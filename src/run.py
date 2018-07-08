from time import sleep
from mininet.net import Mininet
from mininet.topo import Topo
from mininet.cli import CLI
import sys
import json
import argparse
import logging

from utils.p4_mininet import P4Host
from utils.p4runtime_switch import P4RuntimeSwitch

def main():
  arguments = getArguments()

  runner = Runner(arguments.topo, arguments.pcap_dump)
  runner.start()

def getArguments():
  parser = argparse.ArgumentParser()
  parser.add_argument('-t', '--topo', help='Path to topology json',
                      default='src/topology.json',
                      type=str, required=False,
  )
  parser.add_argument('-p', '--pcap-dump', action='store_true',
                      default=False, required=False
  )
  return parser.parse_args()

class Runner:
  def __init__(self, topoFile, isPcapDump):
    with open(topoFile, 'r') as f:
      self.topoConfig = json.load(f)

    self.isPcapDump = isPcapDump

  def start(self):
    self.createNetwork()
    self.net.start()
    sleep(1)

    self.cli()

  def createNetwork(self):
    logging.info('Building mininet topology.')
    self.topo = Topology(self.topoConfig, self.isPcapDump)

    self.net = Mininet(
      topo=self.topo,
      host=P4Host,
      controller=None
    )

  def program_switches(self):
    for sw_name, sw_dict in self.switches.iteritems():
      if 'cli_input' in sw_dict:
        self.program_switch_cli(sw_name, sw_dict)
      if 'runtime_json' in sw_dict:
        self.program_switch_p4runtime(sw_name, sw_dict)

  def program_hosts(self):
    for host_name in self.topo.hosts():
      h = self.net.get(host_name)
      h_iface = h.intfs.values()[0]
      link = h_iface.link

      sw_iface = link.intf1 if link.intf1 != h_iface else link.intf2
      # phony IP to lie to the host about
      host_id = int(host_name[1:])
      sw_ip = '10.0.%d.254' % host_id

      # Ensure each host's interface name is unique, or else
      # mininet cannot shutdown gracefully
      h.defaultIntf().rename('%s-eth0' % host_name)
      # static arp entries and default routes
      h.cmd('arp -i %s -s %s %s' % (h_iface.name, sw_ip, sw_iface.mac))
      h.cmd('ethtool --offload %s rx off tx off' % h_iface.name)
      h.cmd('ip route add %s dev %s' % (sw_ip, h_iface.name))
      h.setDefaultRoute("via %s" % sw_ip)

  def cli(self):
    for h in self.net.hosts:
      h.describe()

    for s in self.net.switches:
      s.describe()

    CLI(self.net)

class Topology(Topo):
  def __init__(self, topoConfig, isPcapDump, **kwargs):
    Topo.__init__(self, **kwargs)

    self.node = {}

    for hostName, config in topoConfig['hosts'].items():
      self.node[hostName] = self.addHost(
        hostName,
        mac=config['mac'],
        ip=config['ip'],
      )

    for p4Name, switches in topoConfig['switches'].items():
      p4JsonPath = 'build/%s.json' % p4Name

      for swName, config in switches.items():
        self.node[swName] =self.addSwitch(
          swName,
          sw_path='simple_switch_grpc',
          json_path=p4JsonPath,
          grpc_port = config['grpc_port'],
          pcap_dump=isPcapDump,
          cls=P4RuntimeSwitch,
        )

    for node1, node2, port1, port2 in topoConfig['links']:
      self.addLink(node1, node2, port1, port2)

if '__main__' == __name__:
  main()
