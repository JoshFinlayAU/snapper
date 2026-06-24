import Foundation

/// Realistic Dell iDRAC 9 Redfish JSON payloads (trimmed) for decoding tests.
enum Fixtures {
    static let serviceRoot = #"""
    {
      "@odata.id": "/redfish/v1",
      "Id": "RootService",
      "Name": "Root Service",
      "RedfishVersion": "1.13.0",
      "Product": "Integrated Dell Remote Access Controller",
      "Vendor": "Dell",
      "UUID": "00000000-0000-0000-0000-000000000000",
      "Systems": { "@odata.id": "/redfish/v1/Systems" },
      "Chassis": { "@odata.id": "/redfish/v1/Chassis" },
      "Managers": { "@odata.id": "/redfish/v1/Managers" },
      "SessionService": { "@odata.id": "/redfish/v1/SessionService" }
    }
    """#

    static let computerSystem = #"""
    {
      "@odata.id": "/redfish/v1/Systems/System.Embedded.1",
      "Id": "System.Embedded.1",
      "Name": "System",
      "Manufacturer": "Dell Inc.",
      "Model": "PowerEdge R740",
      "SKU": "ABCD123",
      "SerialNumber": "CN1234567890",
      "HostName": "esxi-host-01",
      "PowerState": "On",
      "BiosVersion": "2.19.1",
      "SystemType": "Physical",
      "UUID": "4c4c4544-0042-4310-8044-b1c04f303233",
      "Status": { "State": "Enabled", "Health": "OK", "HealthRollup": "OK" },
      "ProcessorSummary": {
        "Count": 2,
        "Model": "Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz",
        "CoreCount": 40,
        "LogicalProcessorCount": 80,
        "Status": { "Health": "OK" }
      },
      "MemorySummary": {
        "TotalSystemMemoryGiB": 384,
        "Status": { "Health": "OK" }
      },
      "BootProgress": { "LastState": "OSRunning" },
      "Processors": { "@odata.id": "/redfish/v1/Systems/System.Embedded.1/Processors" },
      "Memory": { "@odata.id": "/redfish/v1/Systems/System.Embedded.1/Memory" },
      "Storage": { "@odata.id": "/redfish/v1/Systems/System.Embedded.1/Storage" },
      "EthernetInterfaces": { "@odata.id": "/redfish/v1/Systems/System.Embedded.1/EthernetInterfaces" },
      "Actions": {
        "#ComputerSystem.Reset": {
          "target": "/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset",
          "ResetType@Redfish.AllowableValues": [
            "On", "ForceOff", "ForceRestart", "GracefulShutdown", "GracefulRestart", "Nmi"
          ]
        }
      }
    }
    """#

    static let thermal = #"""
    {
      "@odata.id": "/redfish/v1/Chassis/System.Embedded.1/Thermal",
      "Temperatures": [
        {
          "MemberId": "0",
          "Name": "Inlet Temp",
          "ReadingCelsius": 22,
          "UpperThresholdCritical": 43,
          "UpperThresholdNonCritical": 38,
          "PhysicalContext": "Intake",
          "Status": { "State": "Enabled", "Health": "OK" }
        },
        {
          "MemberId": "1",
          "Name": "CPU1 Temp",
          "ReadingCelsius": 55,
          "UpperThresholdCritical": 91,
          "PhysicalContext": "CPU",
          "Status": { "State": "Enabled", "Health": "OK" }
        }
      ],
      "Fans": [
        {
          "MemberId": "0",
          "Name": "System Board Fan1A",
          "Reading": 7680,
          "ReadingUnits": "RPM",
          "MinReadingRange": 600,
          "MaxReadingRange": 18000,
          "Status": { "State": "Enabled", "Health": "OK" }
        }
      ]
    }
    """#

    static let power = #"""
    {
      "@odata.id": "/redfish/v1/Chassis/System.Embedded.1/Power",
      "PowerControl": [
        {
          "MemberId": "0",
          "Name": "System Power Control",
          "PowerConsumedWatts": 210,
          "PowerCapacityWatts": 1500,
          "PowerMetrics": {
            "IntervalInMin": 60,
            "MinConsumedWatts": 180,
            "MaxConsumedWatts": 300,
            "AverageConsumedWatts": 215
          },
          "PowerLimit": { "LimitInWatts": 1400 }
        }
      ],
      "PowerSupplies": [
        {
          "MemberId": "0",
          "Name": "PSU1",
          "Manufacturer": "Dell",
          "Model": "PWR SPLY,750W,RDNT,LITEON",
          "PowerCapacityWatts": 750,
          "LastPowerOutputWatts": 105,
          "LineInputVoltage": 233,
          "Status": { "State": "Enabled", "Health": "OK" }
        },
        {
          "MemberId": "1",
          "Name": "PSU2",
          "Manufacturer": "Dell",
          "PowerCapacityWatts": 750,
          "LastPowerOutputWatts": 110,
          "Status": { "State": "Enabled", "Health": "OK" }
        }
      ]
    }
    """#

    static let drive = #"""
    {
      "@odata.id": "/redfish/v1/Systems/System.Embedded.1/Storage/Drives/Disk.0",
      "Id": "Disk.0",
      "Name": "SSD 0",
      "Model": "MZ7LH960HAJR0D3",
      "Manufacturer": "SAMSUNG",
      "SerialNumber": "S4M2NX0M1234",
      "MediaType": "SSD",
      "Protocol": "SATA",
      "CapacityBytes": 960197124096,
      "FailurePredicted": false,
      "Status": { "State": "Enabled", "Health": "OK" }
    }
    """#
}
