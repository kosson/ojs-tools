# OJS Docker Setup

This is a Dockerized setup for Open Journal Systems (OJS) 3.5.0-3 version with automatic configuration.

## Initial Setup

Rename the example environment file:

```bash
mv .env.example .env
```

Edit the `.env` file to set your desired database password and other environment variables:

```env
DB_PASS=your_secure_password
```

Reflect those changes in the `./volumes/config/pkp.config.inc.php` file if needed, but the setup script will handle most configurations automatically.

Now, run the setup script to prepare the configuration:

```bash
./setup-ojs.sh
```

This script will:

- Generate a secure application encryption key (`app_key`)
- Configure database settings from your `.env` file
- Ensure all configuration is ready for deployment

## 2. Start the Containers

```bash
docker compose up -d
```

## 3. Install OJS

### ⚠️ Known Issue: ROR Dataset Crash

The OJS 3.5.0-3 web installer crashes at the final step when downloading the ROR (Research Organization Registry) dataset. This is a known issue with the official PKP image. **We have a permanent fix!** included in the following steps.

#### 🚀 Quick Installation Steps

##### 1. First Time Setup

```bash
# Generate app_key and configure database
./setup-ojs.sh
```

The `setup-ojs.sh` script automatically:

1. **Generates App Key**: Creates a random 32-byte encryption key required by Laravel/OJS
2. **Configures Database**: Reads `.env` and updates `pkp.config.inc.php` with correct database settings
3. **Validates Configuration**: Ensures all required settings are in place

```bash
# Start containers
docker compose up -d
```

##### 2. Run Web Installer

1. Visit `http://localhost:8080` in your browser and complete the installation wizard
2. Fill in the installation form:
   - Locale: `en` (English)
   - Admin username: Choose your username (e.g., `admin`)
   - Admin password: Choose a strong password
   - Admin email: Your email address
   - Database settings: (auto-filled from .env)
3. Fill in the correct credentials and database info
   - **Database host:** `db`
   - **Database name:** `pkp`
   - **Database user:** `pkp`
   - **Database password:** (the value of `DB_PASS` in your `.env` file)
4. Click "Install OJS"
5. **Wait... it will crash with Error 500** (this is expected!)

The crash happens because the installer tries to download a large ROR dataset which fails in this Docker setup.

##### 3. Complete Installation

```bash
# Fix the crashed installation
./complete-installation.sh
```

##### 4. Access OJS

- URL: http://localhost:8080
- Login with the admin credentials you created in step 2

## 📋 Management Scripts

| Script | Purpose |
|--------|---------|
| `setup-ojs.sh` | Generate app_key and configure database from .env |
| `complete-installation.sh` | Fix installation after ROR crash |
| `check-installation.sh` | Verify OJS installation health |

## 🔧 Troubleshooting

### Containers keep restarting?

```bash
docker logs pkp_app_ojs
```

### Still getting Error 500 after completion script?

```bash
# Check database
docker exec pkp_db_ojs mariadb -upkp -pcine4re4re pkp -e "SELECT * FROM versions"

# Verify installation status
./check-installation.sh
```

### Need to start fresh?

```bash
# Stop and remove everything
docker compose down -v

# Clean volumes
rm -rf volumes/logs/app/* volumes/private/* volumes/public/*

# Start over from step 1
./setup-ojs.sh
docker compose up -d
```

## Files Modified

- `volumes/config/pkp.config.inc.php` - Main OJS configuration file
  - Sets `app_key` (auto-generated if empty)
  - Configures database connection (host, user, password, name)

## Replication on Another Machine

To replicate this setup on another machine:

1. Copy the entire project directory
2. Run `./setup-ojs.sh`
3. Run `docker compose up -d`
4. Complete the web installation wizard

The setup script ensures the configuration is properly initialized regardless of the machine.

## Configuration Files

- `.env` - Environment variables for Docker Compose
- `volumes/config/pkp.config.inc.php` - OJS configuration (auto-configured by setup script)
- `docker-compose.yml` - Docker services definition
- `Dockerfile` - OJS container image build instructions

## Health Check

Run the health check script to verify your installation:

```bash
./check-installation.sh
```

This will check:

- Container status
- Database connectivity  
- Configuration correctness
- File permissions
- HTTP response

## Troubleshooting

### App Key Error

If you see "No application encryption key has been specified":

- Run `./setup-ojs.sh` again
- Restart containers: `docker compose restart app`

### Database Connection Error

If the app can't connect to the database:

- Verify `.env` contains correct `DB_*` values
- Run `./setup-ojs.sh` to update configuration
- Check that database container is running: `docker compose ps`

### Permission Issues

If you get permission errors running the setup script:

```bash
sudo chown -R $USER:$USER volumes/config
chmod 755 volumes/config
chmod 644 volumes/config/pkp.config.inc.php
```

## Database Persistence

**Note:** When you run `docker compose down`, the database is removed because database volumes are commented out in `docker-compose.yml`.

To persist data across restarts, uncomment the database volume lines in `docker-compose.yml`:

```yaml
volumes:
  - ./volumes/db:/var/lib/mysql
```

Then the database will survive `docker compose down` and `docker compose up` cycles.

## Advanced: Custom Configuration

You can manually edit `volumes/config/pkp.config.inc.php` for advanced configuration. Just make sure the `app_key` is set (run `./setup-ojs.sh` if unsure).

## Support

For OJS-specific questions, see the official documentation:
- https://docs.pkp.sfu.ca/learning-ojs/

For Docker-specific issues with this setup:

- Check logs: `docker compose logs app`
- Check container status: `docker compose ps`
- Run health check: `./check-installation.sh`


## 📚 Detailed Documentation

See [PERMANENT-FIX-GUIDE.md](PERMANENT-FIX-GUIDE.md) for:

- Technical details about the fix
- Complete troubleshooting guide
- Explanation of why the ROR crash happens
- Docker and OJS configuration details

## 🎯 What We Fixed

1. ✅ SSL certificate missing → Auto-generated in entrypoint
2. ✅ Config file modification conflicts → Custom entrypoint bypasses this
3. ✅ Permission denied errors → Entrypoint sets correct permissions
4. ✅ ROR dataset crash → Completion script finishes installation
5. ✅ Error 500 after install → Completion script fixes database

## 📝 Default Credentials

After fresh installation:

- **Root DB Password**: `cine4re4re` (from .env)
- **OJS Admin**: Whatever you created in the web installer

**⚠️ IMPORTANT**: Change the default database password in `.env` before production deployment!

## AI usage

This installation suite was created with the assistance of Claude Sonnet 4.5 to streamline development and documentation. Some back and forth with the AI are documented in the `work.md` file.
