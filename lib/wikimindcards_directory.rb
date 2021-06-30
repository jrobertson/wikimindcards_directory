#!/usr/bin/env ruby

# file: wikimindcards_directory.rb

# description: An experimental MindWords driven wiki editor which uses “cards”.

require 'kramdown'
require 'mindwords'
require 'polyrex-links'
require 'jstreebuilder'
require 'martile'

class WikiMindCardsDirectory
  
  def initialize(dir: '.', debug: false)
    
    @dir = File.expand_path(dir)
    @debug = debug
    
    # open the file if it exists
    mindwords_file = File.join(dir, 'mindwords.txt')
    
    if File.exists? mindwords_file then
      
      @mw = MindWords.new(mindwords_file)
      
      # create the activeoutline document if it doesn't already exist
      outline_txt = File.join(dir, 'outline.txt')
      @outline_xml = File.join(dir, 'outline.xml')
      
      if not File.exists? outline_txt then
        
        s = "<?polyrex-links?>\n\n" + @mw.to_outline
        File.write outline_txt, s        
        
      end
      
      @pl = PolyrexLinks.new(outline_txt)      
      
    end
    
  end
  
  def edit(type=:mindwords, title=nil)
    
    case type
    when :link
      linkedit(title)
    when :mindwords
      mindwords_edit()
    when :outline  
      outlinefile_edit()      
    when :tree  
      tree_edit()
    when :card
      cardedit(title)
    end
    
  end

  def import_mindwords(s)
    
    @mw = MindWords.new(s)
    mindwords_file = File.join(@dir, 'mindwords.txt')
    @mw.save mindwords_file
    
    s2 = "<?polyrex-links?>\n\n" + @mw.to_outline
    outline_txt = File.join(@dir, 'outline.txt')
    
    @pl = PolyrexLinks.new(s2)
    @pl.save outline_txt

    
  end
  
  def update(type, title=nil, s)
    
    case type
    when :mindwords
      mindwords_update(s)      
    when :link
      linkupdate(title, s)
    when :card
      cardupdate(title, s)
    when :outline
      outlinefile_update(s)      
    end
    
  end

  # options: :mindwords, :tree, :link, :card
  #  
  def view(type=:mindwords, title=nil)
    
    case type
    when :mindwords
      @mw.to_s
    when :mindwords_tree
      @mw.to_outline
    when :tree  
      treeview()
    when :index
      indexview()
    when :card
      cardview(title)
    end
    
  end
  
  private
  
  def cardedit(rawtitle)
    
    title = rawtitle.downcase.gsub(/ +/,'-')

    file = title + '.txt'
    filepath = File.join(@dir, file)
    
    kvx = if File.exists? filepath then
      Kvx.new(filepath)
    else
      Kvx.new({summary: {title: rawtitle}, body: {md: '', url: ''}}, \
              debug: false)
    end
    
    %Q(<form action="cardupdate" method="post">
      <input type='hidden' name='title' value="#{rawtitle}"/>
      <textarea name="kvxtext" cols="73" rows="17">#{kvx.to_s}</textarea>
      <input type="submit" value="apply"/>
    </form>
    )
  end    
  
  def cardupdate(rawtitle, rawkvxtext)
    
    title = rawtitle.downcase.gsub(/ +/,'-')
    kvx = Kvx.new rawkvxtext.gsub(/\r/,'')

    file = title + '.txt'
    filepath = File.join(@dir, file)
        
    kvx.save filepath
        
    found = @pl.find_all_by_link_title rawtitle
    
    found.each do |link|
    
      url = if kvx.body[:url].length > 1 then
        kvx.body[:url]
      else
        '/do/activeoutline/viewcard?title=' + rawtitle
      end
      
      link.url = url
      
    end
    
    @pl.save @outline_xml

  end
  
  def cardview(rawtitle)
    
    puts 'rawtitle: ' + rawtitle.inspect if @debug
    title = rawtitle.downcase.gsub(/ +/,'-')
    
    file = title + '.txt'
    filepath = File.join(@dir, file)
    puts 'filepath: ' + filepath.inspect if @debug
    
    kvx = if File.exists? filepath then
      Kvx.new(filepath)
    else
      Kvx.new({summary: {title: rawtitle}, body: {md: '', url: ''}}, \
              debug: false)
    end
    
    puts 'kvx: ' + kvx.inspect if @debug
    
    html = if kvx.body[:md].is_a? Hash then
      Kramdown::Document.new(Martile.new(kvx.body[:md][:description].to_s)\
                             .to_html).to_html
    else
      ''
    end
    
    %Q(<h1></h1>
    <ul>
      <li><label>info:</label> #{ html }</li>
      <li><label>url:</label> <a href="#{kvx.url}">#{kvx.url}</a></li>
    </ul>
    <a href="editcard?title=#{rawtitle}">edit</a>
    )    
  end
  
  def linkedit(rawtitle)
    
    r = @pl.find_by_link_title rawtitle
    
    "<form action='updatelink' type='psot'>
      <input type='hidden' name='title' value='#{r.title}'/>    
      <input type='input' name='url' value='#{r.url}'/>
      <input type='submit' value='apply'/>
    </form>
    "
    
  end
  
  def linkupdate(rawtitle, rawurl)
    
    r = @pl.find_by_link_title rawtitle
    return unless r
    
    r.url = rawurl
    
    @outline_xml = File.join(@dir, 'outline.xml') unless @outline_xml
    @pl.save @outline_xml

  end
  
  def indexview()
    
    a = @pl.index
    
    raw_links = a.map do |title, rawurl, path|
    
      anchortag = if rawurl.empty? then
        "<a href='editcard?title=#{title}' style='color: red'>#{title}</a>"
      else
        "<a href='viewcard?title=#{title}'>#{title}</a>"
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
  
  def mindwords_edit()
    
    %Q(<form action="fileupdate" method="post">
      <textarea name="treelinks" cols="73" rows="17">#{@mw.to_s}</textarea>
      <input type="submit" value="apply"/>
    </form>
    )
    
  end
  
  def mindwords_update(s)
    
    @mw = MindWords.new(s)
    
    pl = @pl.migrate @mw.to_outline
    pl.save @outline_xml    
    @pl = pl
    
  end      
  
  def outlinefile_edit()
    
    %Q(<form action="fileupdate" method="post">
      <textarea name="treelinks" cols="73" rows="17">#{@pl.to_s}</textarea>
      <input type="submit" value="apply"/>
    </form>
    )
    
  end  
  
  def outlinefile_update(s)
    
    @pl = PolyrexLinks.new
    @pl.import s
    
  end    
  
  def tree_edit()
        
    base_url = 'linkedit?title='
    @pl.each_recursive { |x| x.url =  base_url + x.title }            
    jtb = JsTreeBuilder.new({src: @pl, type: :plain, debug: true})
        
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


    jtb = JsTreeBuilder.new({src: @pl, type: :plain, debug: false})
    html = "<div class='newspaper1'>#{jtb.to_html}</div>"
    
    style = "
<style>
.newspaper2 {
  columns: 100px 3;
}
ul {list-style-type: none; background-color: transparent; margin: 0.1em 0.1em; padding: 0.3em 1.3em}
ul li {background-color: transparent; margin: 0.1em 0.1em; padding: 0.3em 0.3em}
</style>
"

    style + "\n" + html    
    
  end
  
end


module Wmcd

  class Server < OneDrb::Server

    def initialize(host: '127.0.0.1', port: '21200', dir: '.')

      super(host: host, port: port, obj: WikiMindCardsDirectory.new(dir: dir))

    end

  end

  class Client < OneDrb::Client

    def initialize(host: '127.0.0.1', port: '21200')
      super(host: host, port: port)
    end
  end

end
