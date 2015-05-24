ActiveAdmin.register Item do
  actions :all, :except => [:edit]
  permit_params :number, :country
  TMP = '/tmp/'

  scope :all, default: true
  scope :_new
  scope :done
  scope :in_progress
  #scope :failed
  scope :invalid

  index do 
    selectable_column
    column '' do |r|
      if r.status == Item::NEW
        raw 'Image not<br/>scraped'
      elsif r.status == Item::INVALID
        raw 'No Image'
      else
        link_to image_tag(r.image_url, height: '70', width: '50'), r.url, :target => "_blank"
      end
    end
    column :number do |r|
      if r.status == Item::INVALID
        r.number
      else
        link_to r.number, details_admin_item_path(r)
      end
    end
    column :country
    column :price, sortable: :price do |r|
      number_with_delimiter r.price if r.price
    end
    column :category, sortable: :category do |r|
      if r.category
        r.category.split(" › ").last
      end
    end
    column :title, sortable: :title do |r|
      div :style => 'min-width: 250px;max-width:450px' do 
        r.title
      end
    end
    column :description, sortable: :description do |r|
      div :style => 'min-width: 350px;max-width:450px' do 
        r.description
      end
    end
    column :sizes, sortable: :sizes do |r|
      div :style => 'min-width: 150px;max-width:250px' do 
        r.sizes
      end
    end
    column :colors, sortable: :colors do |r|
      div :style => 'min-width: 150px;max-width:250px' do 
        r.colors
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
    column :updated_at, sortable: :updated_at do |r|
      time_ago_in_words(r.updated_at)
    end
    column :status, sortable: :status do |r|
      status_tag r.status
    end
    column :export do |r|
      link_to 'CSV', export_statistics_admin_item_path(r)
    end
  end

  action_item(only: :index) do
    link_to "Import", import_admin_items_path
  end

  collection_action :import, :method => :get do
    # something here
  end

  member_action :details, method: :get do
    @item = Item.find(params[:id])
    @page_title = 'Item: ' + @item.number
  end

  collection_action :do_import, :method => :post do
    tmp_name = Digest::SHA1.hexdigest(rand(1000000).to_s)
    path = File.join(TMP, tmp_name)
    File.open(path, "wb") { |f| f.write(params[:file].read) }
    Item::import(path)
    render json: {}
  end

  member_action :statistics, method: :get do 
    item = Item.find(params[:id])
    render json: item.get_statistics(params[:from], params[:to])
  end

  member_action :export_statistics, method: :get do 
    item = Item.find(params[:id])
    path = File.join('/tmp/', "item-#{item.number}-#{Time.now.strftime('%Y.%m.%d')}.csv")
    item.item_statistics.to_csv(path)
    send_file path, :type => "application/text", :x_sendfile => true
  end

  

  form do |f|
    f.inputs Item.model_name.human do 
      f.input :number
      f.input :country, as: :select, collection: ['US', 'UK']
      f.actions
    end
  end

  filter :country, as: :select, collection: proc { Item.uniq.pluck(:country) }
  filter :status, as: :select, collection: proc { Item.uniq.pluck(:status) }
  filter :number
  filter :price
  filter :title
  filter :description
  filter :rank
  filter :qty_left
  filter :updated_at
  filter :created_at

end
