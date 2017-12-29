require 'spec_helper'

describe ProjectsController, '(JavaScript fixtures)', type: :controller do
  include JavaScriptFixturesHelpers

  let(:admin) { create(:admin) }
  let(:namespace) { create(:namespace, name: 'frontend-fixtures') }
  let(:project) { create(:project, namespace: namespace, path: 'builds-project') }

  render_views

  before(:all) do
    clean_frontend_fixtures('projects/')
  end

  before do
    sign_in(admin)
  end

  after do
    remove_repository(project)
  end

  it 'projects/dashboard.html.raw' do |example|
    get :show,
      namespace_id: project.namespace.to_param,
      id: project

    expect(response).to be_success
    store_frontend_fixture(response, example.description)
  end
end
