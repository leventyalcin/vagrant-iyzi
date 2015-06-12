# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

class VirtualBox

	INFRA_DIR = File.expand_path('../..', __FILE__)

	VBOX_PATH = `which VBoxManage 2>/dev/null`.strip
	VBOX_VERSION = `#{VBOX_PATH} --version 2>/dev/null`.strip
	VBOX_MINVERSION = '4.3.26r98988'
	VBOX_CONFIGS_PATH = "#{INFRA_DIR}/vagrant.d"
	VBOX_CONFIGS_DEFAULT = "#{VBOX_CONFIGS_PATH}/default.yaml"
	VBOX_CONFIGS_ENABLED = "#{VBOX_CONFIGS_PATH}/boxes-enabled"

	VAGRANT_PATH = `which vagrant 2>/dev/null`.strip
	VAGRANT_PLUGINS = [ 'vagrant-hostmanager', 'vagrant-vbguest', 'vagrant-share', 'vagrant-yaml' ]

	def check_installation
		if not VBOX_PATH or not VAGRANT_PATH or VBOX_VERSION < VBOX_MINVERSION
			return nil
		end
		
		VAGRANT_PLUGINS.each do |plugin|
			if not Vagrant.has_plugin?(plugin)
				puts "#{plugin} is not installed. Will be installed"
				system("#{VAGRANT_PATH} plugin install #{plugin}")
			end
		end
		true
	end

	def check_configs
		if Dir.glob("#{VBOX_CONFIGS_ENABLED}/*.yaml").size == 0 or not File.exists?("#{VBOX_CONFIGS_DEFAULT}")
			return nil
		end
		true
	end

	def config_default
		return YAML.load_file(VBOX_CONFIGS_DEFAULT)
	end

	def config_files
		return Dir.glob("#{VBOX_CONFIGS_ENABLED}/*.yaml")
	end

	def config_merge(config_file)
		default = config_default
		yaml = YAML.load_file "#{config_file}"

		if default.is_a?(Hash) and yaml.is_a?(Hash)
			default.deep_merge!(yaml)
		end

		return default
	end
end

class ::Hash
	def self.deep_merge!(tgt_hash, src_hash)
		tgt_hash.merge!(src_hash) { |key, oldval, newval|
			if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
				deep_merge!(oldval, newval)
    		else
      			newval
    		end
  		}
	end
end

Vagrant.require_version ">= 1.7.0"

virtualbox = VirtualBox.new
if not virtualbox.check_installation
	fail "Couldn't find VirtualBox in PATH or version is outdated. Please install/update VirtualBox first"
end 

if not virtualbox.check_configs
	fail "There is no enabled box under #{VirtualBox::VBOX_CONFIGS_ENABLED} or #{VirtualBox::VBOX_CONFIGS_DEFAULT} is not exit.\n"
end

Vagrant.configure(2) do |vagrant_config|

	virtualbox.config_files.each do |yaml_config|
		vm_config = virtualbox.config_merge(yaml_config)

		vagrant_config.vm.define vm_config[:box][:hostname] do |guest_config|
			guest_config.vm.box = vm_config[:guest][:box]
			guest_config.vm.box_check_update = vm_config[:guest][:box_check_update]
			guest_config.vm.box_version = vm_config[:guest][:box_version] if vm_config[:guest].has_key?(:box_version)

			guest_config.vm.hostname = "#{vm_config[:box][:hostname]}#{'.'+vm_config[:box][:domainname] if vm_config[:box][:domainname]}"
			guest_config.vm.network "public_network", ip: "#{vm_config[:box][:ip]}"

			guest_config.vm.provider 'virtualbox' do |v|
        v.customize [ 'modifyvm', :id, '--memory', vm_config[:guest][:ram] ]
        v.customize [ 'modifyvm', :id, '--cpus',   vm_config[:guest][:cpu] ]
				if vm_config[:guest][:cores] > 1
          v.customize ['modifyvm', :id, '--ioapic', 'on']
        end
			end
		end
	end
end
