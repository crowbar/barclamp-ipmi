#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Note : This script runs on both the admin and compute nodes.
# It intentionally ignores the bios->enable node data flag.

include_recipe "utils"

unless node[:platform] == "windows" or ::File.exists?("/usr/sbin/ipmitool") or ::File.exists?("/usr/bin/ipmitool")
  package "ipmitool" do
    case node[:platform]
    when "ubuntu","debian","suse"
      package_name "ipmitool"
    when "redhat","centos"
      package_name "OpenIPMI-tools"
    end
    action :install
  end
end

unsupported = [ "KVM", "Bochs", "VMWare Virtual Platform", "VMware Virtual Platform", "VirtualBox" ]

node.set["crowbar_wall"] = {} unless node["crowbar_wall"]
node.set["crowbar_wall"]["ipmi"] = {} unless node["crowbar_wall"]["ipmi"]
node.set["crowbar_wall"]["status"] = {} unless node["crowbar_wall"]["status"]
node.set["crowbar_wall"]["status"]["ipmi"] = {} unless node["crowbar_wall"]["status"]["ipmi"]
node.save

if node[:platform] == "windows"
    node.set["crowbar_wall"]["status"]["ipmi"]["messages"] = [ "Unsupported platform - turning off ipmi for this node" ]
    node.set[:ipmi][:bmc_enable] = false
    node.save
    return
elsif node[:ipmi][:bmc_enable]
  if unsupported.member?(node[:dmi][:system][:product_name])
    node.set["crowbar_wall"]["status"]["ipmi"]["messages"] = [ "Unsupported platform: #{node[:dmi][:system][:product_name]} - turning off ipmi for this node" ]
    node.set[:ipmi][:bmc_enable] = false
    node.save
    return
  end

  ruby_block "discover ipmi settings" do
    block do
      if unsupported.member?(node[:dmi][:system][:product_name])
        return
      end
      case node[:platform]
      when "ubuntu","debian","suse"
        %x{modprobe ipmi_si; sleep 10}
      end
      %x{modprobe ipmi_devintf ; sleep 15}
      (1..11).each do |n|
        %x{ipmitool lan print #{n} 2> /dev/null | grep -q ^Set}
        if $?.exitstatus == 0
          node.set["crowbar_wall"]["ipmi"]["channel"] = n
          break
        end
      end

      if node["crowbar_wall"]["ipmi"]["channel"].nil?
        node.set["crowbar_wall"]["status"]["ipmi"]["messages"] = [ "Could not find IPMI lan channel: #{node[:dmi][:system][:product_name]} - turning off ipmi for this node" ]
        node.set[:ipmi][:bmc_enable] = false
      else
        ipmiprint = %x{ipmitool lan print #{node["crowbar_wall"]["ipmi"]["channel"]}}
        if $?.exitstatus == 0
          ipmiprint.split("\n").each do |l|
            if l.start_with?("IP Address   ")
              node.set["crowbar_wall"]["ipmi"]["address"] = l.split(":")[1].strip
            elsif l.start_with?("Default Gateway IP ")
              node.set["crowbar_wall"]["ipmi"]["gateway"] = l.split(":")[1].strip
            elsif l.start_with?("Subnet Mask ")
              node.set["crowbar_wall"]["ipmi"]["netmask"] = l.split(":")[1].strip
            end
          end
          node.set["crowbar_wall"]["ipmi"]["mode"] = %x{ipmitool delloem lan get}.strip
        else
          node.set["crowbar_wall"]["status"]["ipmi"]["messages"] = [ "Could not get IPMI lan info: #{node[:dmi][:system][:product_name]} - turning off ipmi for this node" ]
          node.set[:ipmi][:bmc_enable] = false
        end
      end
      node.save
      case node[:platform]
      when "ubuntu","debian"
        %x{rmmod ipmi_si}
      end
      %x{rmmod ipmi_devintf ; rmmod ipmi_msghandler}
    end
    action :create
  end
end

