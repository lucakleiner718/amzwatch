ActiveAdmin.register Setting do
  actions :all, :except => [:new, :remove, :destroy, :delete, :show]
  permit_params :value

  index do 
    column :name
    column :value
    column :updated_at
    actions
  end

  form do |f|
    f.inputs Setting.model_name.human do 
      f.input :name, :as => :string, :input_html => { :readonly => true }
      f.input :value
      f.actions
    end
  end

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


end
