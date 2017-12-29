require 'spec_helper'

describe ProjectPolicy do
  set(:guest) { create(:user) }
  set(:reporter) { create(:user) }
  set(:developer) { create(:user) }
  set(:master) { create(:user) }
  set(:owner) { create(:user) }
  set(:admin) { create(:admin) }
  let(:project) { create(:project, :public, namespace: owner.namespace) }

  let(:base_guest_permissions) do
    %i[
      read_project read_board read_list read_wiki read_issue read_label
      read_milestone read_project_snippet read_project_member
      read_note create_project create_issue create_note
      upload_file
    ]
  end

  let(:base_reporter_permissions) do
    %i[
      download_code fork_project create_project_snippet update_issue
      admin_issue admin_label admin_list read_commit_status read_build
      read_container_image read_pipeline read_environment read_deployment
      read_merge_request download_wiki_code
    ]
  end

  let(:team_member_reporter_permissions) do
    %i[build_download_code build_read_container_image]
  end

  let(:developer_permissions) do
    %i[
      admin_milestone admin_merge_request update_merge_request create_commit_status
      update_commit_status create_build update_build create_pipeline
      update_pipeline create_merge_request create_wiki push_code
      resolve_note create_container_image update_container_image
      create_environment create_deployment
    ]
  end

  let(:base_master_permissions) do
    %i[
      delete_protected_branch update_project_snippet update_environment
      update_deployment admin_project_snippet
      admin_project_member admin_note admin_wiki admin_project
      admin_commit_status admin_build admin_container_image
      admin_pipeline admin_environment admin_deployment
    ]
  end

  let(:public_permissions) do
    %i[
      download_code fork_project read_commit_status read_pipeline
      read_container_image build_download_code build_read_container_image
      download_wiki_code
    ]
  end

  let(:owner_permissions) do
    %i[
      change_namespace change_visibility_level rename_project remove_project
      archive_project remove_fork_project destroy_merge_request destroy_issue
    ]
  end

  # Used in EE specs
  let(:additional_guest_permissions) { [] }
  let(:additional_reporter_permissions) { [] }
  let(:additional_master_permissions) { [] }

  let(:guest_permissions) { base_guest_permissions + additional_guest_permissions }
  let(:reporter_permissions) { base_reporter_permissions + additional_reporter_permissions }
  let(:master_permissions) { base_master_permissions + additional_master_permissions }

  before do
    project.add_guest(guest)
    project.add_master(master)
    project.add_developer(developer)
    project.add_reporter(reporter)
  end

  def expect_allowed(*permissions)
    permissions.each { |p| is_expected.to be_allowed(p) }
  end

  def expect_disallowed(*permissions)
    permissions.each { |p| is_expected.not_to be_allowed(p) }
  end

  it 'does not include the read_issue permission when the issue author is not a member of the private project' do
    project = create(:project, :private)
    issue   = create(:issue, project: project)
    user    = issue.author

    expect(project.team.member?(issue.author)).to be false

    expect(Ability).not_to be_allowed(user, :read_issue, project)
  end

  context 'when the feature is disabled' do
    subject { described_class.new(owner, project) }

    before do
      project.project_feature.update_attribute(:wiki_access_level, ProjectFeature::DISABLED)
    end

    it 'does not include the wiki permissions' do
      expect_disallowed :read_wiki, :create_wiki, :update_wiki, :admin_wiki, :download_wiki_code
    end
  end

  context 'issues feature' do
    subject { described_class.new(owner, project) }

    context 'when the feature is disabled' do
      it 'does not include the issues permissions' do
        project.issues_enabled = false
        project.save!

        expect_disallowed :read_issue, :create_issue, :update_issue, :admin_issue
      end
    end

    context 'when the feature is disabled and external tracker configured' do
      it 'does not include the issues permissions' do
        create(:jira_service, project: project)

        project.issues_enabled = false
        project.save!

        expect_disallowed :read_issue, :create_issue, :update_issue, :admin_issue
      end
    end
  end

  shared_examples 'project policies as anonymous' do
    context 'abilities for public projects' do
      context 'when a project has pending invites' do
        let(:group) { create(:group, :public) }
        let(:project) { create(:project, :public, namespace: group) }
        let(:user_permissions) { [:create_project, :create_issue, :create_note, :upload_file] }
        let(:anonymous_permissions) { guest_permissions - user_permissions }

        subject { described_class.new(nil, project) }

        before do
          create(:group_member, :invited, group: group)
        end

        it 'does not grant owner access' do
          expect_allowed(*anonymous_permissions)
          expect_disallowed(*user_permissions)
        end
      end
    end

    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }

      subject { described_class.new(nil, project) }

      it { is_expected.to be_banned }
    end
  end

  shared_examples 'project policies as guest' do
    subject { described_class.new(guest, project) }

    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }
      let(:reporter_public_build_permissions) do
        reporter_permissions - [:read_build, :read_pipeline]
      end

      it do
        expect_allowed(*guest_permissions)
        expect_disallowed(*reporter_public_build_permissions)
        expect_disallowed(*team_member_reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end

      context 'public builds enabled' do
        it do
          expect_allowed(*guest_permissions)
          expect_allowed(:read_build, :read_pipeline)
        end
      end

      context 'when public builds disabled' do
        before do
          project.update(public_builds: false)
        end

        it do
          expect_allowed(*guest_permissions)
          expect_disallowed(:read_build, :read_pipeline)
        end
      end

      context 'when builds are disabled' do
        before do
          project.project_feature.update(builds_access_level: ProjectFeature::DISABLED)
        end

        it do
          expect_disallowed(:read_build)
          expect_allowed(:read_pipeline)
        end
      end
    end
  end

  shared_examples 'project policies as reporter' do
    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }

      subject { described_class.new(reporter, project) }

      it do
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*team_member_reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end
  end

  shared_examples 'project policies as developer' do
    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }

      subject { described_class.new(developer, project) }

      it do
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*team_member_reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_disallowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end
  end

  shared_examples 'project policies as master' do
    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }

      subject { described_class.new(master, project) }

      it do
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*team_member_reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*master_permissions)
        expect_disallowed(*owner_permissions)
      end
    end
  end

  shared_examples 'project policies as owner' do
    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }

      subject { described_class.new(owner, project) }

      it do
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*team_member_reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*master_permissions)
        expect_allowed(*owner_permissions)
      end
    end
  end

  shared_examples 'project policies as admin' do
    context 'abilities for non-public projects' do
      let(:project) { create(:project, namespace: owner.namespace) }

      subject { described_class.new(admin, project) }

      it do
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_disallowed(*team_member_reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*master_permissions)
        expect_allowed(*owner_permissions)
      end
    end
  end

  it_behaves_like 'project policies as anonymous'
  it_behaves_like 'project policies as guest'
  it_behaves_like 'project policies as reporter'
  it_behaves_like 'project policies as developer'
  it_behaves_like 'project policies as master'
  it_behaves_like 'project policies as owner'
  it_behaves_like 'project policies as admin'
end
