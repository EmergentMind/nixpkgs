{ lib, fetchFromGitHub, elkVersion, buildGoModule, libpcap, nixosTests, systemd, config }:

let beat = package: extraArgs: buildGoModule (lib.attrsets.recursiveUpdate (rec {
  pname = package;
  version = elkVersion;

  src = fetchFromGitHub {
    owner = "elastic";
    repo = "beats";
    rev = "v${version}";
    hash = "sha256-0qwWHRIDLlnaPOCRmiiFGg+/jdanWuQtggM2QSaMR1o=";
  };

  vendorHash = "sha256-rwCCpptppkpvwQWUtqTjBUumP8GSpPHBTCaj0nYVQv8=";

  subPackages = [ package ];

  meta = with lib; {
    homepage = "https://www.elastic.co/products/beats";
    license = licenses.asl20;
    maintainers = with maintainers; [ fadenb basvandijk dfithian ];
    platforms = platforms.linux;
  };
}) extraArgs);
in
rec {
  auditbeat = beat "auditbeat" { meta.description = "Lightweight shipper for audit data"; };
  filebeat = beat "filebeat" {
    meta.description = "Lightweight shipper for logfiles";
    buildInputs = [ systemd ];
    tags = [ "withjournald" ];
    postFixup = ''
      patchelf --set-rpath ${lib.makeLibraryPath [ (lib.getLib systemd) ]} "$out/bin/filebeat"
    '';
  };
  heartbeat = beat "heartbeat" { meta.description = "Lightweight shipper for uptime monitoring"; };
  metricbeat = beat "metricbeat" {
    meta.description = "Lightweight shipper for metrics";
    passthru.tests =
      lib.optionalAttrs config.allowUnfree (
        assert metricbeat.drvPath == nixosTests.elk.unfree.ELK.elkPackages.metricbeat.drvPath;
        {
          elk = nixosTests.elk.unfree.ELK;
        }
      );
  };
  packetbeat = beat "packetbeat" {
    buildInputs = [ libpcap ];
    meta.description = "Network packet analyzer that ships data to Elasticsearch";
    meta.longDescription = ''
      Packetbeat is an open source network packet analyzer that ships the
      data to Elasticsearch.

      Think of it like a distributed real-time Wireshark with a lot more
      analytics features. The Packetbeat shippers sniff the traffic between
      your application processes, parse on the fly protocols like HTTP, MySQL,
      PostgreSQL, Redis or Thrift and correlate the messages into transactions.
    '';
  };
}
