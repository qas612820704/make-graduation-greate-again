#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x0800;
const bit<19> ECN_THRESHOLD = 10;

typedef bit<9> egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
  macAddr_t dstAddr;
  macAddr_t srcAddr;
  bit<16> etherType;
}

header ipv4_t {
  bit<4>    version;
  bit<4>    ihl;
  bit<6>    diffserv;
  bit<2>    ecn;
  bit<16>   totalLen;
  bit<16>   identification;
  bit<3>    flags;
  bit<13>   fragOffset;
  bit<8>    ttl;
  bit<8>    protocol;
  bit<16>   hdrChecksum;
  ip4Addr_t srcAddr;
  ip4Addr_t dstAddr;
}

struct metadata {

}

struct headers {
  ethernet_t ethernet;
  ipv4_t ipv4;
}

parser _Parser(
  packet_in packet,
  out headers hdr,
  inout metadata meta,
  inout standard_metadata_t standard_metadata
) {

  state start {
    transition parse_ethernet;
  }

  state parse_ethernet {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      TYPE_IPV4: parse_ipv4;
      default: accept;
    }
  }

  state parse_ipv4 {
    packet.extract(hdr.ipv4);
    transition accept;
  }
}

control _VerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

control _Ingress(
  inout headers hdr,
  inout metadata meta,
  inout standard_metadata_t standard_metadata
) {

  action drop() {
    mark_to_drop();
  }

  action port_forward(egressSpec_t port) {
    standard_metadata.egress_spec = port;
  }

  table ipv4_lpm {
    key = {
      hdr.ipv4.dstAddr: lpm;
    }

    actions = {
      port_forward;
      NoAction;
    }

    default_action = NoAction();
  }

  apply {
    if (hdr.ipv4.isValid()) {
      ipv4_lpm.apply();
    }
  }
}

control _Egress(
  inout headers hdr,
  inout metadata meta,
  inout standard_metadata_t standard_metadata
) {

  action mark_ecn() {
    hdr.ipv4.ecn = 3;
  }

  apply {
    if (hdr.ipv4.ecn == 1 || hdr.ipv4.ecn == 2) {
      if (standard_metadata.enq_qdepth >= ECN_THRESHOLD) {
        mark_ecn();
      }
    }
  }
}

control _ComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
	      hdr.ipv4.diffserv,
	      hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

control _Deparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

V1Switch(
  _Parser(),
  _VerifyChecksum(),
  _Ingress(),
  _Egress(),
  _ComputeChecksum(),
  _Deparser()
) main;