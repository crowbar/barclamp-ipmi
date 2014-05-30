#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class IpmiService < ServiceObject
  
  def initialize(thelogger)
    super(thelogger)
    @bc_name = "ipmi"
  end

  class << self
    def role_constraints
      {
        "ipmi-configure" => {
          "unique" => false,
          "count" => -1
        }
      }
    end
  end
  
  def create_proposal
    @logger.debug("IPMI create_proposal: entering")
    base = super
    @logger.debug("IPMI create_proposal: exiting")
    base
  end
  
  def transition(inst, name, state)
    @logger.debug("IPMI transition: make sure that network role is on all nodes: #{name} for #{state}")
    
    #
    # If we are discovering the node, make sure that we add the ipmi role to the node
    #
    if state == "discovering"
      @logger.debug("IPMI transition: discovering state for #{name} for #{state}")
      db = ProposalObject.find_proposal "ipmi", inst
      role = RoleObject.find_role_by_name "ipmi-config-#{inst}"
      result = add_role_to_instance_and_node("ipmi", inst, name, db, role, "ipmi-discover")
      @logger.debug("ipmi transition: leaving from installed state for #{name} for #{state}")
      a = [200, { :name => name } ] if result
      a = [400, "Failed to add role to node"] unless result
      return a
    end
    
    #
    # If we are discovering the node, make sure that we add the ipmi role to the node
    #
    if state == "discovered"
      @logger.debug("IPMI transition: installed state for #{name} for #{state}")
      db = ProposalObject.find_proposal "ipmi", inst
      role = RoleObject.find_role_by_name "ipmi-config-#{inst}"
      result = add_role_to_instance_and_node("ipmi", inst, name, db, role, "ipmi-configure")
      
      node = NodeObject.find_node_by_name(name)
      # Add the bmc routing roles as appropriate.
      bmc_role = node.admin? ? "bmc-nat-router" : "bmc-nat-client"
      result = add_role_to_instance_and_node("ipmi", inst, name, db, role, bmc_role)

      ns = NetworkService.new @logger
      if role and !role.default_attributes["ipmi"]["use_dhcp"]
        @logger.debug("IPMI transition: Allocate bmc address for #{name}")
        suggestion = node["crowbar_wall"]["ipmi"]["address"] rescue nil
        suggestion = nil if role and role.default_attributes["ipmi"]["ignore_address_suggestions"]
        result = ns.allocate_ip("default", "bmc", "host", name, suggestion)
        @logger.error("Failed to allocate bmc address for: #{name}: #{result[0]}") if result[0] != 200
        @logger.debug("ipmi transition: Done Allocate bmc address for #{name}")
        result = result[0] == 200
      else
        # This enables other system to function because the bmc data is on the node, 
        # but no address is assigned.
        result = ns.enable_interface("default", "bmc", name)
        @logger.error("Failed to enable bmc interface for: #{name}: #{result[0]}") if result[0] != 200
        @logger.debug("ipmi transition: Done enable interface bmc address for #{name}")
        result = result[0] == 200
      end

      @logger.debug("ipmi transition: leaving from installed state for #{name} for #{state}")
      a = [200, { :name => name } ] if result
      a = [400, "Failed to add role to node"] unless result
      return a
    end
    
    @logger.debug("ipmi transition: leaving for #{name} for #{state}")
    [200, { :name => name } ]
  end
  
end
