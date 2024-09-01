# WireGuard Client Management Script

This script, `manage_wireguard_clients.sh`, allows you to easily add and remove WireGuard clients on a server running a WireGuard interface (`wg1`). It automates the generation of keys, configuration files, and QR codes for clients, as well as updates the server configuration without disconnecting existing peers.

## Features

- **Add new clients**: Generate private and public keys, add the client to the WireGuard server configuration (`wg1.conf`), and create a client configuration file.
- **Remove clients**: Remove the client's configuration from the WireGuard server and delete associated files.
- **Seamless configuration update**: Update the WireGuard server configuration without disconnecting existing peers.
- **Generate QR codes**: Generate QR codes for easy client configuration import on mobile devices.

## Prerequisites

- WireGuard installed on your server.
- `qrencode` installed for generating QR codes.
- Bash shell environment.

## Installation

1. **Clone the repository or copy the script** to your server.

2. **Make the script executable**:

```bash
chmod +x manage_wireguard_clients.sh
 ```


## Usage
Adding a new client

### To add a new WireGuard client, run the script with the add option:

```bash
sudo ./manage_wireguard_clients.sh <client_name> add
```
*    <client_name>: The name of the client to be added (e.g., client1).

The script will:

*    Generate a new pair of keys for the client.
*   Add a new peer to the wg1.conf configuration file with a label # peer_<client_name>.
*    Create a client configuration file in /etc/wireguard/clients/<client_name>.
*    Optionally generate a QR code for easy import on mobile devices.

### Removing a client

To remove a WireGuard client, run the script with the delete option:

```bash
sudo ./manage_wireguard_clients.sh <client_name> delete
```
*    <client_name>: The name of the client to be removed (e.g., client1).

The script will:

*    Remove the peer configuration from the wg1.conf file.
*    Delete all client-related files from /etc/wireguard/clients/<client_name>.

### Example

1) Add a client:

```bash
sudo ./manage_wireguard_clients.sh user1 add
```

2) Remove a client:

```bash
sudo ./manage_wireguard_clients.sh user1 delete
```

## Script Workflow
### Adding a Client

1)    Check available IP addresses: The script checks for the next available IP in the range 10.66.66.200/32 - 10.66.66.254/32.
2)    Generate keys: Generates a private and public key pair for the new client.
3)    Create client directory and save keys: Saves the keys in /etc/wireguard/clients/<client_name>.
4)    Update WireGuard server configuration: Adds a new peer to the wg1.conf file with the client's public key and IP.
5)    Apply configuration changes: Uses wg setconf to apply changes without disconnecting existing peers.
6)    Generate client configuration file: Creates a client configuration file for use with WireGuard clients.
7)    Optionally generate a QR code: For easy setup on mobile devices.

### Removing a Client

1)    Remove peer configuration: Deletes the peer entry from the wg1.conf file using a label # peer_<client_name>.
2)    Delete client files: Removes all files related to the client from /etc/wireguard/clients/<client_name>.
3)    Apply configuration changes: Uses wg setconf to apply changes without disconnecting existing peers.

### Notes

*    Ensure that WireGuard is correctly installed and configured on your server.
*    This script should be run with sudo privileges to modify the WireGuard configuration and create/delete client files.
