# fpga-i2c-address-translator
FPGA-based I²C address translator in Verilog. Acts as an I²C slave to the bus master and master to the target device, dynamically remapping addresses to avoid conflicts. Supports bidirectional read/write, standard I²C timing, FSM-based design, simulation, and testbenches.
FPGA-Based I²C Master-Slave Communication
This repository implements an FPGA-based I²C master-slave system in Verilog. It demonstrates basic I²C communication, including start/stop conditions, address transmission, read/write operations, and acknowledgment (ACK) handling. The design is suitable for simulation and FPGA deployment and serves as a foundation for more advanced I²C modules, like address translators.

I²C Master:
Generates START and STOP conditions.
Sends 7-bit slave addresses with R/W bit.
Transmits 8-bit data.
Handles slave ACK responses.
Configurable I²C clock frequency (100 kHz / 400 kHz).

I²C Slave:
Receives 7-bit address and data bytes.
Sends ACK to master when address matches.
Handles read/write operations.

Open-Drain Bus Model:
Simulates realistic bidirectional SDA/SCL behavior.
