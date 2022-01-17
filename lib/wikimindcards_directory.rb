#!/usr/bin/env ruby

# file: wikimindcards_directory.rb

# description: An experimental MindWords driven wiki editor which uses “cards”.

require 'kramdown'
require 'mindwords'
require 'polyrex-links'
require 'jstreebuilder'
require 'martile'
require 'onedrb'
require 'hashcache'
require 'dxlite'



KVX_XSL =<<EOF
<xsl:stylesheet xmlns:xsl='http://www.w3.org/1999/XSL/Transform' version='1.0'>
<xsl:output method="xml" omit-xml-declaration="yes" />

  <xsl:template match='*'>

   <xsl:apply-templates select='summary' />

    <xsl:element name='div'>
<!--
        <xsl:attribute name='created'>
        <xsl:value-of select='@created'/>
      </xsl:attribute>
      <xsl:attribute name='last_modified'>
        <xsl:value-of select='@last_modified'/>
      </xsl:attribute>
-->
      <xsl:apply-templates select='body' />

      <a href="editcard?title={summary/title}">edit</a>

    </xsl:element>

  </xsl:template>

  <xsl:template match='summary'>

    <h1>
    	<xsl:value-of select='title' />
    </h1>

  </xsl:template>


  <xsl:template match='body'>

    <ul>

    	<li><label>info: </label> <xsl:copy-of select='desc' /></li>
    	<li><label>url: </label> <xsl:value-of select='url' /></li>
    	<xsl:element name='li'>
        <xsl:attribute name='class'><xsl:value-of select='wiki/@class' /></xsl:attribute>
        <label>wiki: </label> <xsl:copy-of select='wiki' />
      </xsl:element>

    </ul>

  </xsl:template>

</xsl:stylesheet>
EOF

class WikiMindCardsDirectory
  include RXFHelperModule

  class MindWordsX < MindWords
    include RXFHelperModule

    def initialize(dir, s='')

      @dir = dir
      super(s)

    end

    def edit()

      %Q(<form action="fileupdate" method="post">
        <textarea name="treelinks" cols="73" rows="17">#{self.to_s}</textarea>
        <input type="submit" value="apply"/>
      </form>
      )

    end


    def import(s='')

      super(s)

      FileX.mkdir_p File.join(@dir, 'data')
      mindwords_file = File.join(@dir, 'data', 'mindwords.txt')
      self.save mindwords_file

    end

  end

  class PxLinks < PolyrexLinks
    include RXFHelperModule

    def initialize(dir, raws)

      @dir = dir

      if raws.lines.length > 1 then

        s = if raws.lstrip.lines.first =~ /<\?polyrex/ then
          raws
        else
          "<?polyrex-links?>\n\n" + raws
        end

        super(s)

        outline_xml = File.join(@dir, 'data', 'outline.xml')
        save outline_xml

      elsif raws.length > 1

        # it must be a filename

        if FileX.exists? raws then
          super(raws)
        end

      end

    end

    def linkedit(rawtitle)

      r = find_by_link_title rawtitle
      return 'title not found' unless r

      "<form action='updatelink' type='post'>
        <input type='hidden' name='title' value='#{r.title}'/>
        <input type='input' name='url' value='#{r.url}'/>
        <input type='submit' value='apply'/>
      </form>
      "

    end

    def linkupdate(rawtitle, rawurl)

      r = find_by_link_title rawtitle
      return unless r

      r.url = rawurl

      outline_xml = File.join(@dir, 'data', 'outline.xml')
      save outline_xml

      # ... also save it to the associated card (kvx document).

      title = rawtitle.downcase.gsub(/ +/,'-')
      file = title + '.txt'
      filepath = File.join(@dir, file)

      kvx = Kvx.new filepath
      kvx.url = rawurl
      kvx.save filepath

    end

    def indexview(base_url='')

      a = index()

      raw_links = a.map do |title, rawurl, path|

        anchortag = if rawurl.empty? then
          "<a href='%seditcard?title=%s' style='color: red'>%s</a>" % [base_url, title, title]
        else
          "<a href='%sviewcard?title=%s'>%s</a>" % [base_url, title, title]
        end
        [title, anchortag]

      end

      links = raw_links.to_h

      a2 = a.map do |title, rawurl, rawpath|

        path = rawpath[0..-2].reverse.map {|x| links[x]}.join('/')
        "<tr><td>%s</td><td>%s</td></tr>" % [links[title], path]

      end

      "<table>#{a2.join("\n")}</table>"
    end

    def outlinefile_edit()

      %Q(<form action="fileupdate" method="post">
        <textarea name="treelinks" cols="73" rows="17">#{self.to_s}</textarea>
        <input type="submit" value="apply"/>
      </form>
      )

    end

    def tree_edit()

      links = PxLinks.new(@dir, self.to_s)
      base_url = 'linkedit?title='
      links.each_recursive { |x| x.url =  base_url + x.title }
      jtb = JsTreeBuilder.new({src: links, type: :plain, debug: false})

    style = "
<style>
.newspaper1 {
  columns: 100px 3;
}
ul {list-style-type: none; background-color: transparent; margin: 0.1em 0.1em; padding: 0.3em 1.3em}
ul li {background-color: transparent; margin: 0.1em 0.1em; padding: 0.3em 0.3em}
</style>
"
      html = "<div class='newspaper1'>#{jtb.to_html}</div>"
      style + "\n" + html
    end

    def treeview()

      jtb = JsTreeBuilder.new({src: self, type: :plain, debug: false})
      jtb.links {|x| x.attributes[:target] = 'icontent'}
      html = "<div class='newspaper2'>#{jtb.to_html}</div>"

    style = "
<style>
.newspaper1 {
  columns: 100px 3;
}
ul {list-style-type: none; background-color: transparent; margin: 0.1em 0.1em; padding: 0.3em 1.3em}
ul li {background-color: transparent; margin: 0.1em 0.1em; padding: 0.3em 0.3em}
</style>
"

      style + "\n" + html

    end
  end

  class Card
  end

  # the directory being read should be the root directory of the
  # project data store
  #
  def initialize(dir: '.', dxpath: nil, debug: false)

    @dir = File.expand_path(dir)
    @dxpath = dxpath
    @debug = debug

    # attempt to read the mindwords and outline (polyrex-links) files
    #
    read()

  end

  def edit(type=:mindwords, title=nil)

    case type
    when :link
      @pl.linkedit(title)
    when :mindwords
      @mw.edit()
    when :outline
      @pl.outlinefile_edit()
    when :tree
      @pl.tree_edit()
    when :card
      cardedit(title)
    end

  end

  def import_mindwords(s)

    @mw = MindWordsX.new(@dir, s)
    @pl = PxLinks.new(@dir, @mw.to_outline)

  end

  def read(path='')

    data_dir = File.join(@dir, *path.split('/'), 'data')

    # open the file if it exists
    mindwords_file = File.join(data_dir, 'mindwords.txt')

    if FileX.exists? mindwords_file then

      @mw = MindWordsX.new(@dir, mindwords_file)

      # create the activeoutline document if it doesn't already exist
      outline_txt = File.join(data_dir, 'outline.txt')
      @outline_xml = File.join(data_dir, 'outline.xml')

      if not FileX.exists? outline_txt then

        s = "<?polyrex-links?>\n\n" + @mw.to_outline
        FileX.write outline_txt, s

      end

      @pl = PxLinks.new(@dir, outline_txt)

    end

    self

  end

  def update(type, title=nil, s)

    case type
    when :mindwords
      mindwords_update(s)
    when :link
      @pl.linkupdate(title, s)
    when :card
      cardupdate(title, s)
    when :outline
      @pl = PxLinks.new @dir, s
    end

  end

  # options: :mindwords, :tree, :link, :card
  #
  def view(type=:mindwords, title: nil, base_url: '')

    puts 'inside view' if @debug
    case type
    when :mindwords
      @mw.to_s
    when :mindwords_tree
      @mw.to_outline
    when :tree
      @pl.treeview()
    when :index
      @pl.indexview(base_url)
    when :card
      cardview(title)
    end

  end

  private

  def cardedit(rawtitle)

    title = rawtitle.downcase.gsub(/ +/,'-')

    file = title + '.txt'
    filepath = File.join(@dir, file)

    kvx = if FileX.exists? filepath then
      Kvx.new(filepath)
    else
      Kvx.new({summary: {title: rawtitle}, body: {md: '', url: '',wiki: rawtitle.capitalize}}, \
              debug: false)
    end

    %Q(<form action="cardupdate" method="post">
      <input type='hidden' name='title' value="#{rawtitle}"/>
      <textarea name="kvxtext" cols="73" rows="17">#{kvx.to_s}</textarea>
      <input type="submit" value="apply"/>
    </form>
    )
  end

  def cardupdate(rawtitle, rawkvxtext, url_base: '')

    title = rawtitle.downcase.gsub(/ +/,'-')
    kvx = Kvx.new rawkvxtext.gsub(/\r/,'')

    file = title + '.txt'
    filepath = File.join(@dir, file)

    kvx.save filepath

    found = @pl.find_all_by_link_title rawtitle

    found.each do |link|

      url = if kvx.body[:url].length > 1 then
        kvx.body[:url]
#      else
#        url_base + 'viewcard?title=' + rawtitle
      end

      link.url = url

    end

    @pl.save @outline_xml

  end

  def cardview(rawtitle)

    puts 'rawtitle: ' + rawtitle.inspect if @debug
    filetitle = rawtitle.downcase.gsub(/ +/,'-')

    file = filetitle + '.txt'
    filepath = File.join(@dir, file)
    puts 'filepath: ' + filepath.inspect if @debug

    kvx = if FileX.exists? filepath then
      Kvx.new(filepath)
    else
      Kvx.new({summary: {title: rawtitle}, body: {md: '', url: '', wiki: rawtitle.capitalize}}, \
              debug: false)
    end

    puts 'kvx: ' + kvx.inspect if @debug

    md = if kvx.body[:md].is_a? Hash then
      kvx.body[:md][:description].to_s
    else
      kvx.body[:md].to_s
    end

    puts 'after md: ' + md.inspect if @debug

    html = Kramdown::Document.new(Martile.new(md).to_html).to_html

    # This is the path to the mymedia-wiki directory ->
    dx = DxLite.new @dxpath, debug: false

    title = rawtitle[/^#{rawtitle}(?= +#)/i]

    record = dx.all.find do |post|
      post.title =~ /^#{rawtitle}(?= +#)/i
    end

    doc = kvx.to_doc

    e = doc.root.element('body/wiki')

    if e then

      link = Rexle::Element.new('a').add_text(e.text)

      if record then
        link.attributes[:href] = '/do/wiki/view?file=' + File.basename(record.url)
      else
        tags = @mw.hashtags(e.text)

        href = '/do/wiki/create?title=' + URI::Parser.new.escape(e.text)
        href += '&amp;amp;tags=' + e.text.to_s.split(/ +/).join(' ') + ' ' + tags.join(' ') if tags

        link.attributes[:href] = href
        e.attributes[:class] = 'newpage'
      end

      e.text = ''
      e.add link
    end


    doc.root.element('body').add Rexle.new('<desc>' + html + '</desc>')

    nokodoc   = Nokogiri::XML(doc.xml)
    #xslt  = Nokogiri::XSLT(File.read(File.join(@dir, 'kvx.xsl')))
    xslt  = Nokogiri::XSLT(KVX_XSL)
    style = '<style>li.newpage a {color: #e33;}</style>'
    card = xslt.apply_to(nokodoc).to_s
    style + "\n\n" + card

  end

  def mindwords_update(s)

    @mw = MindWordsX.new(@dir, s)

    pl = @pl.migrate @mw.to_outline
    pl.save @outline_xml
    @pl = pl

  end


end


class MultiWmcd

  def initialize(dir: '.', dxpath: nil)

    @dir, @dxpath = dir, dxpath
    @hc = HashCache.new
    cache_read()

  end

  def read(path='')
    cache_read(path)
  end

  private

  def cache_read(path='')

    @hc.read(path) do
      wmcd = WikiMindCardsDirectory.new(dir: @dir, dxpath: @dxpath)
      wmcd.read(path)
    end

  end

end

module Wmcd

  class Server < OneDrb::Server

    def initialize(host: '127.0.0.1', port: '21200', dir: '.', dxpath: nil)

      super(host: host, port: port, obj: MultiWmcd.new(dir: dir, dxpath: dxpath))

    end

  end

  class Client < OneDrb::Client

    def initialize(host: '127.0.0.1', port: '21200')
      super(host: host, port: port)
    end
  end

end
