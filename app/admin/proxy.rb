ActiveAdmin.register Proxy do
  permit_params :ip, :port, :username, :password, :status, :hit_count, :enable
  actions :all, except: [:show]

# See permitted parameters documentation:
# https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
#
# permit_params :list, :of, :attributes, :on, :model
#
# or
#
# permit_params do
#   permitted = [:permitted, :attributes]
#   permitted << :other if resource.something?
#   permitted
# end

  collection_action :import, :method => :get do
    
  end
  
  controller do 
    def create
      # do not go to the VIEW page after create
      create! do |format|
        format.html { redirect_to admin_proxies_path }
      end
    end

    def update
      # do not go to the VIEW page after create
      update! do |format|
        format.html { redirect_to admin_proxies_path }
      end
    end
  end  

  form do |f|
    f.inputs Proxy.model_name.human do 
      f.input :ip
      f.input :port
      f.input :username
      f.input :password, :input_html => { :type => 'text' } 
      f.input :hit_count
      f.input :failure_count
      f.input :status, as: :select, collection: [Proxy::DEAD, Proxy::ALIVE]
      f.actions
    end
  end

  index do 
    selectable_column
    column :ip
    column :port
    column :username
    column :password
    column :hit_count
    column :failure_count
    column :status, sortable: :status do |r|
      status_tag r.status
    end
    actions
  end

  collection_action :do_import, :method => :post do
    done, failed = Proxy.import(params[:proxies])
    redirect_to admin_proxies_path, :notice => "#{done.count} proxies imported, #{failed.count} failed"
  end

  action_item(only: :index) do
    link_to "Import Proxies", import_admin_proxies_path
  end

  form do |f|
    f.inputs Proxy.model_name.human do 
      f.input :ip
      f.input :port
      f.input :username
      f.input :password
      #f.input :password, :input_html => { :type => 'text' } 
      f.actions
    end
  end

  filter :ip
  filter :port
  filter :username
  filter :hit_count
  filter :failure_count
  filter :status


end
