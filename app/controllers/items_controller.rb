class ItemsController < InheritedResources::Base
  private
  def item_params
    params.require(:item).permit(:number, :title, :description, :price, :upc, :rank, :status, :url)
  end
end

