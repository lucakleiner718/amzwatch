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
    column '' do |r|
      if r.status == Item::NEW
        raw 'Image not<br/>scraped'
      else
        link_to image_tag(r.image_url, height: '70', width: '50'), r.image_url, :target => "_blank"
      end
    end
    column :country
    column :number do |r|
      link_to r.number, r.url, :target => "_blank" 
    end
    column :category, sortable: :category do |r|
      if r.category
        r.category.split(" › ").last
      end
    end
    column :title, sortable: :title do |r|
      if r.title
        arr = r.title.split(/\s+/)
        arr[0..20].join(" ") + ((arr.count > 21) ? "..." : "")
      end
    end
    column :description, sortable: :description do |r|
      if r.description
        arr = r.description.split(/\s+/)
        arr[0..20].join(" ") + ((arr.count > 21) ? "..." : "")
      end
    end
    column :rank
    column :qty_left, sortable: :qty_left do |r|
      if r.notes
        raw r.qty_left.to_s + "<br>(#{r.notes})"
      else
        r.qty_left
      end
    end
    column :updated_at
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
