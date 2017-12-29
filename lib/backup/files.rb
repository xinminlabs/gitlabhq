require 'open3'

module Backup
  class Files
    attr_reader :name, :app_files_dir, :backup_tarball, :files_parent_dir

    def initialize(name, app_files_dir)
      @name = name
      @app_files_dir = File.realpath(app_files_dir)
      @files_parent_dir = File.realpath(File.join(@app_files_dir, '..'))
      @backup_files_dir = File.join(Gitlab.config.backup.path, File.basename(@app_files_dir))
      @backup_tarball = File.join(Gitlab.config.backup.path, name + '.tar.gz')
    end

    # Copy files from public/files to backup/files
    def dump
      FileUtils.mkdir_p(Gitlab.config.backup.path)
      FileUtils.rm_f(backup_tarball)

      if ENV['STRATEGY'] == 'copy'
        cmd = %W(cp -a #{app_files_dir} #{Gitlab.config.backup.path})
        output, status = Gitlab::Popen.popen(cmd)

        unless status.zero?
          puts output
          abort 'Backup failed'
        end

        run_pipeline!([%W(tar -C #{@backup_files_dir} -cf - .), %w(gzip -c -1)], out: [backup_tarball, 'w', 0600])
        FileUtils.rm_rf(@backup_files_dir)
      else
        run_pipeline!([%W(tar -C #{app_files_dir} -cf - .), %w(gzip -c -1)], out: [backup_tarball, 'w', 0600])
      end
    end

    def restore
      backup_existing_files_dir
      create_files_dir

      run_pipeline!([%w(gzip -cd), %W(tar -C #{app_files_dir} -xf -)], in: backup_tarball)
    end

    def backup_existing_files_dir
      timestamped_files_path = File.join(files_parent_dir, "#{name}.#{Time.now.to_i}")
      if File.exist?(app_files_dir)
        FileUtils.mv(app_files_dir, File.expand_path(timestamped_files_path))
      end
    end

    def run_pipeline!(cmd_list, options = {})
      status_list = Open3.pipeline(*cmd_list, options)
      abort 'Backup failed' unless status_list.compact.all?(&:success?)
    end
  end
end
