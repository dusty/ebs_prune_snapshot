# EbsPruneSnapshot

Manage your EBS snapshots on a daily, weekly, and monthly rotation schedule.

Features
 - Keep at least one snapshot of each volume, regardless of the rotation schedule.
 - Saves the youngest snapshot of a particular day as a daily snapshot.
 - Saves the oldest snapshot of any week as a weekly snapshot (Sundays).
 - Saves the oldest snapshot of any 4 week period as a monthly snapshot (Sunday).

Take a look at ebs_snapshot to take the snapshots if you need LVM/XFS
filesystem freezing and/or MySQL locks. (https://github.com/dusty/ebs_snapshot)

## Installation

Add this line to your application's Gemfile:

    gem 'ebs_prune_snapshot'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ebs_prune_snapshot

## Usage

AWS Access Key and AWS Secret Access Key are required.  These options can be
provided through the command line or they may be stored in the environmental
variables of AMAZON_ACCESS_KEY_ID and AMAZON_SECRET_ACCESS_KEY.  Any options
provided through the command line will override the environmental variables.

A daily, weekly, and monthly rotation are also required.  The monthly rotation
is every 4 weeks, so provide 13 to go back a full year.

If you only want to see what would happen if you ran the schedule, then pass
the --dry-run (-n) argument.

Usage: ebs_prune_snapshot [options]
   eg: ebs_snapshot -d 7 -w 12 -m 14

Required rotation configuration
    -d, --daily DAILY                Number of daily snapshots to keep
    -w, --weekly WEEKLY              Number of weekly snapshots to keep
    -m, --monthly MONTHLY            Number of monthly snapshots to keep

AWS Identifications, required unless environmental variables set
    -k, --key KEY                    AWS Access Key (AMAZON_ACCESS_KEY_ID)
    -s, --secret SECRET              AWS Secret Access Key (AMAZON_SECRET_ACCESS_KEY)

Informational arguments
    -n, --dry-run                    Describe what would be done (SAFE)
    -h, --help                       Show Command Help

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
