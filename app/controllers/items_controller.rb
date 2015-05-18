class ItemsController < InheritedResources::Base
  def upload
    if request.post?
      # save to disk
      tmp_name = Digest::SHA1.hexdigest(rand(1000000).to_s)
      path = File.join('/tmp/', tmp_name)
      File.open(path, "wb") { |f| f.write(params[:file].read) }
      Item::import(path)
      render text: tmp_name
    else
      # upload view page
    end
  end

  private
  def item_params
    params.require(:item).permit(:number, :title, :description, :price, :upc, :rank, :status, :url)
  end
end

