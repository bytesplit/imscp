# i-MSCP installation on Ubuntu

## Supported Ubuntu versions

Any LTS version 1.0 Ubuntu 14.04/Trusty Thar

## Installation

### 1. Download and untar the distribution files

```bash
cd /usr/local/src
wget https://github.com/i-MSCP/imscp/archive/<version>.tar.gz
tar -xzf <version>.tar.gz
```

### 2. Change to the newly created directory

```
cd imscp-<version>
```

### 3. Install i-MSCP by running its installer

```bash
perl imscp-installer -d
```

## Upgrade

### 1. Make sure to read the errata file

Before upgrading, you must not forget to read the
[errata file](https://github.com/i-MSCP/imscp/blob/<version>/docs/1.5.x_errata.md)

### 2. Make sure to make a backup of your data

Before any upgrade attempt it is highly recommended to make a backup of the
following directories:

```
/var/www/virtual
/var/mail/virtual
```

These directories hold the data of your customers and it is really important to
backup them for an easy recovering in case something goes wrong during upgrade.

You should also backup all SQL databases.

### 3. Download and untar the distribution files

```bash
cd /usr/local/src
wget https://github.com/i-MSCP/imscp/archive/<version>.tar.gz
tar -xzf <version>.tar.gz
```

### 4. Change to the newly created directory

```
cd imscp-<version>
```

### 5. Update i-MSCP by running its installer

```
perl imscp-installer -d
```
