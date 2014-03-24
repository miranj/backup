backup
======

Shell script to backup and restore databases and files on web servers.

The backup script uses a configuration file where each website is set as a project and can have multiple databases and folder paths for backup. Each backup file is also copied over to a remote location (over SCP/SSH).

*Currently works with MySQL and PostgreSQL databases.*


## Dependencies

- [json.sh](https://github.com/rcrowley/json.sh) *(included as git submodule)*

## Install

1.  Clone project with `--recursive` option to recursively clone the [json.sh](https://github.com/rcrowley/json.sh) submodule.
      
      `> git clone --recursive git@github.com:miranj/backup.git`

2.  Create a `config.json` from `config-sample.json` using appropriate config values.

3.  Protect `config.json`.
      
      `> chmod 600 config.json`

4.  For PostgreSQL, a `.pgpass` file must be placed in the user home directory with database usernames and passwords. Refer [PostgreSQL Password File Documentation](http://www.postgresql.org/docs/9.1/static/libpq-pgpass.html).

5.  For MysQL, a `my.cnf` file *may be* used to provide database usernames and passwords. Refer [MySQL Option File Documentation](https://dev.mysql.com/doc/refman/5.1/en/option-files.html).

6.  Set up a cron job to periodically run the script `backup.sh`
        
        Examples:
        > # 3AM everyday
        > 0 3 * * * <path_to_backup.sh>
        >
        > # Every 30 minutes
        > 0/30 * * * * <path_to_backup.sh>
      
7.  To delete old backups specify a lifetime in the config file, and set up a cron job to periodically run the script `cleanup.sh`
        
        Example:
        > # 3AM every Saturday
        > 0 3 * * 6 <path_to_cleanup.sh>

## Usage

- `./backup.sh` backs up all projects
- `./backup.sh <project-name>` backs up a single project
- `./restore.sh <project-name> <backup-file-path>` restores the project
- `./cleanup.sh` deletes all local backups that are older than the lifetime (as set in config file)
- `./cleanup.sh <project-name>` deletes all local backups of a single project that are older than the lifetime (as set in config file)


## Tests

- Install [Roundup](https://github.com/bmizerany/roundup).
- Copy the config files in `tests/config-sample` to `tests/config` using appropriate config values.
- At the root of the source code run `./tests.sh`.
