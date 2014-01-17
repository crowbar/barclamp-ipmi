# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

## utility to check if a lan parameter needs to be set 
## (if it's current value is different than desired one).
def check_bmc_value(test, desired)
  current = %x{#{test}}
  current = current.chomp.strip
  current.casecmp(desired) == 0
end

action :run do
  name = new_resource.name
  command = new_resource.command
  test = new_resource.test
  value = new_resource.value
  settle_time = new_resource.settle_time

  if ::File.exists?("/sys/module/ipmi_devintf")
    unless check_bmc_value(test, value)
      # Set BMC LAN parameters; we don't use a bash/script resource so we can
      # immediately check if the command failed or not, and save the result
      if system("#{command}")
        %x{sleep #{settle_time}}
        bmc_value_is_set = check_bmc_value(test, value)
      else
        bmc_value_is_set = false
      end

      if bmc_value_is_set
        node["crowbar_wall"]["status"]["ipmi"]["messages"] << "#{name} set to #{value}" unless node.nil?
      else
        node["crowbar_wall"]["status"]["ipmi"]["messages"] << "Unable to set #{name} to #{value}" unless node.nil?
      end
    else
      node["crowbar_wall"]["status"]["ipmi"]["messages"] << "#{name} already set to #{value}" unless node.nil?
    end
  else
    node["crowbar_wall"]["status"]["ipmi"]["messages"] << "Unsupported product found #{node[:dmi][:system][:product_name]} - skipping IPMI:#{name}" unless node.nil?
  end  
  node.save
end

