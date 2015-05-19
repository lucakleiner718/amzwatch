ActiveAdmin.register Item do
  actions :all, :except => [:new]
  TMP = '/tmp/'

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

  scope :all, default: true
  scope :_new
  scope :done
  scope :in_progress
  scope :failed

  index do 
    selectable_column
    column :number
    column :upc
    column :title
    column :description
    column :status, sortable: :status do |r|
      status_tag r.status
    end
  end

  action_item(only: :index) do
    link_to "Import", import_admin_items_path
  end

  collection_action :import, :method => :get do
    # something here
  end

  collection_action :do_import, :method => :post do
    tmp_name = Digest::SHA1.hexdigest(rand(1000000).to_s)
    path = File.join(TMP, tmp_name)
    File.open(path, "wb") { |f| f.write(params[:file].read) }
    Item::import(path)
    render json: {}
  end

end
