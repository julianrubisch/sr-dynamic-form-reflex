Create and manage complex forms with page morphs

**How?**
- A model (`Address`) has associations to two interdependent other models (`Country` => `State`)
- Via a `DynamicFormReflex#refresh` action, manage the `state_id` select box, which depends on the `country`

**Caveat**
To use this with unpersisted records, you will need to adapt the `def resource` method slightly:

```rb
def resource
  @resource ||= if element.dataset.sgid.present?
    element.signed[:sgid] 
  else
    element.dataset.resource_name.classify.new
  end
end
```

**Variations**
- You can also use this with `has_many` associations:

```rb
class Address < ApplicationRecord
  belongs_to :tenant
  has_many :inhabitants
  
  accepts_nested_attributes_for :inhabitants
```

```rb
class Controller
  def edit
    @address = Address.find(params[:id])
    
    @address.inhabitants.build
  end
end
```

```erb
<%= form_with model: @address do |form| %>
  <%= form.label :tenant_id %>
  <%= form.collection_select :tenant_id, Tenant.all, :id, :name, {include_blank: true}, 
    data: {reflex: "change->DynamicForm#refresh", sgid: @address.to_sgid.to_s, 
    resource_name: "address", association: "tenant"} %>
  
  <%= form.fields_for :inhabitants do |inhabitant_fields| %>
    <%= inhabitant_fields.label :inhabitant_id %>
    <%= inhabitant_fields.collection_select :inhabitant_id, @address.tenant&.members || [], :id, :name %>
  <% end %>
<% end %>
```
