#!/usr/bin/env ruby

# file: wikimindcards_directory.rb

# description: An experimental MindWords driven wiki editor which uses “cards”.

require 'kramdown'
require 'mindwords'
require 'polyrex-links'
require 'jstreebuilder'
require 'martile'

class WikiMindCardsDirectory
  
  def initialize(dir: '.')
    
    # open the file if it exists
    mindwords_file = File.join(dir, 'mindwords.txt')
    
    if File.exists? mindwords_file then
      
      @mw = MindWords.new(mindwords_file)
      
      # create the activeoutline document if it doesn't already exist
      outline_file = File.join(dir, 'outline.txt')
      
      if not File.exists? outline_file then
        
        s = "<?polyrex-links?>\n\n" + @mw.to_outline
        File.write outline_file, s        
        
      end
      
      @pl = PolyrexLinks.new(outline_file)      
      
    end
    
  end
  
  def edit(type=:mindwords)
    
    case type
    when :link
      linkedit()      
    when :mindwords
      mindwords_edit()
    when :tree  
      tree_edit()
    when :index
      indexview()
    when :card
      cardedit()      
    end
    
  end  
  
  # options: :mindwords, :tree, :link, :card
  #
  def update(type=:mindwords)
    
  end
  
  def view(type=:mindwords)
    
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
      cardview()
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
      Kvx.new({summary: {title: params['title']}, body: {md: '', url: ''}}, \
              debug: false)
    end
    
    %Q(<form action="cardupdate" method="post">
      <input type='hidden' name='title' value="#{params['title']}"/>
      <textarea name="kvxtext" cols="73" rows="17">#{kvx.to_s}</textarea>
      <input type="submit" value="apply"/>
    </form>
    )
  end    
  
  def cardview(rawtitle)
    
    title = rawtitle.downcase.gsub(/ +/,'-')
    
    file = title + '.txt'
    filepath = File.join(@dir, file)
    
    kvx = if File.exists? filepath then
      Kvx.new(filepath)
    else
      Kvx.new({summary: {title: rawtitle}, body: {md: '', url: ''}}, \
              debug: false)
    end
    
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
  
  def tree_edit()
        
    base_url = 'linkedit?title='
    @pl.each_recursive { |x| x.url =  base_url + x.title }            
    jtb = JsTreeBuilder.new({src: links, type: :plain, debug: true})
        
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

