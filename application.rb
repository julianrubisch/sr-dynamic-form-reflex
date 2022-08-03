require "action_controller/railtie"
require "action_cable/engine"
require "active_model"
require "active_record"
require "nulldb/rails"
require "rails/command"
require "rails/commands/server/server_command"
require "cable_ready"
require "stimulus_reflex"
require "city-state"

module ApplicationCable; end

class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :session_id

  def connect
    self.session_id = request.session.id
  end  
end

class ApplicationCable::Channel < ActionCable::Channel::Base; end

class ApplicationController < ActionController::Base; end

class ApplicationReflex < StimulusReflex::Reflex; end

class DynamicFormReflex < ApplicationReflex
  def refresh
    resource.send("#{element.dataset.association}=", element.value)
    # resource.send("#{element.dataset.association}=", element.dataset.association.classify.safe_constantize.find(element.value))

    instance_variable_set "@#{element.dataset.resource_name}", resource
  end

  def resource
    @resource ||= Address.find(element.dataset.id) # you would do element.signed[:sgid] in a real world app
  end
end

class Address < ActiveRecord::Base
  validates :state, inclusion: { in: -> record { record.states.keys }, allow_blank: true },
                    presence: { if: -> record { record.states.present? } }

  def countries
    CS.countries.with_indifferent_access
  end

  def country_name
    countries[country]
  end

  def states
    CS.states(country).with_indifferent_access
  end

  def state_name
    states[state]
  end
  
  def self.find(id)
    Address.new
  end
end

class DemosController < ApplicationController
  def show
    @address ||= Address.find(1)
    render inline: <<~HTML
      <html>
        <head>
          <title>StimulusReflex Mini Demo</title>
          <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet">
          <%= javascript_include_tag "/index.js", type: "module" %>
        </head>
        <body>
          <div class="container my-5">
            <%= form_for @address, url: "#" do |form| %>              
              <%= form.label :country %>
              <%= form.select :country, @address.countries.invert, {include_blank: true}, data: {reflex: "change->DynamicForm#refresh", id: 1, resource_name: "address", association: "country"} %>
              
              <%= form.label :state %>
              <%= form.select :state, @address.states.invert %>
            <% end %>
          </div>
        </body>
      </html>
    HTML
  end
end

class MiniApp < Rails::Application
  require "stimulus_reflex/../../app/channels/stimulus_reflex/channel"

  config.action_controller.perform_caching = true
  config.consider_all_requests_local = true
  config.public_file_server.enabled = true
  config.secret_key_base = "cde22ece34fdd96d8c72ab3e5c17ac86"
  config.secret_token = "bf56dfbbe596131bfca591d1d9ed2021"
  config.session_store :cache_store
  config.hosts.clear

  Rails.cache = ActiveSupport::Cache::RedisCacheStore.new(url: "redis://localhost:6379/1")
  Rails.logger = ActionCable.server.config.logger = Logger.new($stdout)
  ActionCable.server.config.cable = {"adapter" => "redis", "url" => "redis://localhost:6379/1"}
  StimulusReflex.config.logger = Rails.logger
  
  routes.draw do
    mount ActionCable.server => "/cable"
    get '___glitch_loading_status___', to: redirect('/')
    resource :demo, only: :show
    root "demos#show"
  end
end

ActiveRecord::Base.establish_connection adapter: :nulldb, schema: "schema.rb"

Rails::Server.new(app: MiniApp, Host: "0.0.0.0", Port: ARGV[0]).start
