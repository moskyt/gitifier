framework 'AppKit'
framework 'Foundation'
framework 'Cocoa'
framework 'QuartzCore'
require 'yaml'

CONFIG_FILENAME = 'gitifier.yml'

class Repo
  
  def initialize(dir)
    @dir = dir

    @img_ok = NSImage.new.initWithContentsOfFile 'accept.png'
    @img_dirty = NSImage.new.initWithContentsOfFile 'cancel.png'
    @img_error = NSImage.new.initWithContentsOfFile 'error.png'
    @img_push = NSImage.new.initWithContentsOfFile 'drive_add.png'
    @img_pull = NSImage.new.initWithContentsOfFile 'drive_delete.png'
  end
  
  def attach(menu_item)
    @menu_item = menu_item
  end
  
  def pull
    puts "Pulling #{name}"
    Dir.chdir(@dir) do
      `git pull`
    end
  end
  
  def push
    puts "Pushing #{name}"
    Dir.chdir(@dir) do
      r = `git push`
      if r.include?('[rejected]')
        @error = 'merge'
      end
    end
  end

  def update
    return unless @menu_item
    if @error
      @menu_item.setImage @img_error
    elsif !clean?
      @menu_item.setImage @img_dirty
    elsif needs_to_pull?
      @menu_item.setImage @img_pull
    elsif needs_to_push?
      @menu_item.setImage @img_push
    else
      @menu_item.setImage @img_ok
    end
  end
  
  def fetch
    puts "Fetching #{name}"
    Dir.chdir(@dir) do
      `git fetch --all`
    end
  end
  
  def proceed
    @error = nil
    if clean?
      pull if needs_to_pull?
      push if needs_to_push?
    end
    update
  end
  
  def name
    File.basename(@dir)
  end
  
  def git_status
    Dir.chdir(@dir) do
      `git status`
    end
  end
  
  def clean?
    git_status.include? 'nothing to commit, working directory clean'
  end
  
  def needs_to_pull?
    git_status.include? 'branch is behind'
  end
  
  def needs_to_push?
    git_status.include? 'branch is ahead'
  end
    
end

def pull_all(sender)
  @repos.each do |r|
    r.fetch
    r.pull
    r.update
  end
end

def update_all(sender)
  @repos.each(&:update)
end

def load_repos
  puts "Loading repos"
  @repos = []
  @repo_paths.each do |p|
    puts "Inspecting #{p} ..."
    Dir["#{p}/*"].each do |d|
      if File.directory?(d) and File.exist?(File.join(d, '.git'))
        puts "  - found #{File.basename(d)}"
        @repos << Repo.new(d)
      end
    end
  end
  @repos = @repos.sort_by{|r| r.name}
end

# We build the status bar item menu
def setupMenu(menu)  
  while menu.itemArray.size > 0
    menu.removeItem menu.itemArray.first
  end
  @repos.each_with_index do |r, ri| 
    mi = NSMenuItem.new
    mi.title = r.name
    mi.target = self
    mi.action = "proceed:"
    mi.setRepresentedObject ri
    r.attach mi
    menu.addItem mi
  end

  mi = NSMenuItem.new
  mi.title = "Pull'n'fetch"
  mi.action = 'pull_all:'
  mi.target = self
  menu.addItem mi

  mi = NSMenuItem.new
  mi.title = "Refresh"
  mi.action = 'update_all:'
  mi.target = self
  menu.addItem mi

  mi = NSMenuItem.new
  mi.title = 'Reload cfg&repos'
  mi.action = 'reload:'
  mi.target = self
  menu.addItem mi

  mi = NSMenuItem.new
  mi.title = 'Quit'
  mi.action = 'quit:'
  mi.target = self
  menu.addItem mi

  menu
end

# Init the status bar
def initStatusBar(menu)
  status_bar = NSStatusBar.systemStatusBar
  status_item = status_bar.statusItemWithLength(NSVariableStatusItemLength)
  status_item.setMenu menu 
  img = NSImage.new.initWithContentsOfFile 'bug.png'
  status_item.setImage(img)
end

# Menu Item Actions
# def sayHello(sender)
#     alert = NSAlert.new
#     alert.messageText = 'This is MacRuby Status Bar Application'
#     alert.informativeText = 'Cool, huh?'
#     alert.alertStyle = NSInformationalAlertStyle
#     alert.addButtonWithTitle("Yeah!")
#     response = alert.runModal
# end

def proceed(sender)
  @repos[sender.representedObject.to_i].proceed  
end

def fetchRepos(sender)
  @fetch_index ||= 0
  @fetch_index += 1
  @repos[@fetch_index % @repos.size].fetch
end

def updateRepos(sender)
  @update_index ||= 0
  @update_index += 1
  @repos[@update_index % @repos.size].update
end

def quit(sender)
  app = NSApplication.sharedApplication
  app.terminate(self)
end

def load_config
  raise "[#{CONFIG_FILENAME}] not found!" unless File.exist?(CONFIG_FILENAME)
  yaml = YAML::load(File.open CONFIG_FILENAME)
  @repo_paths = yaml['paths']
end

def reload(sender)
  load_config
  load_repos
  setupMenu(@menu)
  @repos.each(&:update)
end

load_config
load_repos

app = NSApplication.sharedApplication
@menu = NSMenu.new
@menu.initWithTitle 'Gitifier'
setupMenu(@menu)
initStatusBar(@menu)
@repos.each(&:update)
NSTimer.scheduledTimerWithTimeInterval 1, target: self, selector: 'updateRepos:', userInfo: nil, repeats: true
NSTimer.scheduledTimerWithTimeInterval 15, target: self, selector: 'fetchRepos:', userInfo: nil, repeats: true
app.run
