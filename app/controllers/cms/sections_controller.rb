class Cms::SectionsController < Cms::BaseController

  before_filter :load_parent, :only => [:new, :create]
  before_filter :load_section, :only => [:edit, :update, :destroy, :move]
  before_filter :set_toolbar_tab
  
  helper_method :public_groups
  helper_method :cms_groups

  def index
    redirect_to cms_sitemap_path
  end

  def show
    redirect_to cms_sitemap_path
  end
  
  def new
    @section = @parent.sections.build
    @section.groups = @parent.groups
  end
  
  def create
    @section = Section.new(params[:section])
    @section.parent = @parent
    @section.groups = @section.parent.groups unless current_user.able_to?(:administrate)
    if @section.save
      flash[:notice] = "Section '#{@section.name}' was created"
      redirect_to [:cms, @section]
    else
      render :action => 'new'
    end    
  end

  def edit
  end
  
  def update
    params[:section].delete('group_ids') if params[:section] &&  !current_user.able_to?(:administrate)
    @section.attributes = params[:section]
    if @section.save
      flash[:notice] = "Section '#{@section.name}' was updated"
      redirect_to [:cms, @section]
    else
      render :action => 'edit'
    end      
  end
  
  def destroy
    respond_to do |format|
      if @section.deletable? && @section.destroy
        message = "Section '#{@section.name}' was deleted."
        format.html { flash[:notice] = message; redirect_to(cms_sitemap_url) }
        format.json { render :json => {:success => true, :message => message } }
      else
        message = "Section '#{@section.name}' could not be deleted"
        format.html { flash[:error] = message; redirect_to(cms_sitemap_url) }
        format.json { render :json => {:success => false, :message => message } }
      end
    end
  end  
  
  def move
    if params[:section_id]
      @move_to = Section.find(params[:section_id])
    else
      @move_to = Section.root.first
    end
  end
  
  def file_browser              
    @section = Section.find_by_name_path(params[:CurrentFolder])
    if request.post? && params[:NewFile]
      handle_file_browser_upload
    else
      render_file_browser
    end
  end
  
  protected
    def load_parent
      @parent = Section.find(params[:section_id])
      raise Cms::Errors::AccessDenied unless current_user.able_to_edit?(@parent)
    end

    def load_section
      @section = Section.find(params[:id])
      raise Cms::Errors::AccessDenied unless current_user.able_to_edit?(@section)
    end

    def handle_file_browser_upload
      begin
        abstract_file_block_attributes = {
          :name => params[:NewFile].original_filename,
          :attachment_section_id => @section.id,
          :attachment_file => params[:NewFile],
          :attachment_file_path => "#{@section.path}#{Time.now.strftime("%m/%d/%Y/")}#{Time.now.strftime("%I/%M/%S")}.#{params[:NewFile].original_filename}"
        }
        case params[:Type].downcase
        when "file"
          file = FileBlock.create!(abstract_file_block_attributes)
          file.publish!
        when "image" 
          image = ImageBlock.create!(abstract_file_block_attributes)
          image.publish!
        end
        result = "0"
      rescue Exception => e
        result = "1,'#{escape_javascript(e.message)}'"
      end  
      render :text => %Q{<script type="text/javascript">window.parent.frames['frmUpload'].OnUploadCompleted(#{result});</script>}, :layout => false      
    end
    
    def render_file_browser
      headers['Content-Type'] = "text/xml"
      @files = case params[:Type].downcase
               when "file"
                 FileBlock.by_section(@section)
               when "image" 
                 ImageBlock.by_section(@section)
               else
                 @section.pages
               end
       render 'cms/sections/file_browser.xml.builder', :layout => false
    end

    def public_groups
      @public_groups ||= Group.public.all(:order => "groups.name")
    end

    def cms_groups
      @cms_groups ||= Group.cms_access.all(:order => "groups.name")
    end

    def set_toolbar_tab
      @toolbar_tab = :sitemap
    end
end
