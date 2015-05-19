ActiveAdmin.register Task do
  permit_params :pid, :name, :progress, :status
  actions :all, :except => [:new, :edit, :remove, :show]
  
  controller do 
    def create
      # do not go to the VIEW page after create
      create! do |format|
        format.html { redirect_to admin_tasks_path }
      end
    end

    def update
      # do not go to the VIEW page after create
      update! do |format|
        format.html { redirect_to admin_tasks_path }
      end
    end
  end  

  form do |f|
    f.inputs Task.model_name.human do 
      f.input :category_id, as: :select, collection: Category.all.map{|c| [c.name, c.id] }
      # f.input :scraping_date, as: :datepicker
      f.actions
    end
  end

  member_action :stop, :method => :get do
    t = Task.find(params[:id])
    t.stop!
    redirect_to admin_tasks_path
  end

  member_action :start, :method => :get do
    t = Task.find(params[:id])
    t.start!
    redirect_to admin_tasks_path
  end

  index do 
    column :status, sortable: :status do |r|
      status_tag r.status
    end
    column :name
    column :progress
    column 'Action' do |r|
      r.update_status!
      if r.running?
        link_to 'Stop', stop_admin_task_path(r), method: :get
      else
        link_to 'Start', start_admin_task_path(r), method: :get
      end
      
    end
  end

  filter :name
  filter :status
end
