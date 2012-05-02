require "ebs_prune_snapshot/version"
require 'AWS'

module EbsPruneSnapshot
  class Base

    attr_reader :rotation, :aws

    def initialize(args={})
      @aws = Aws.new(args[:aws])
      @rotation = Rotation.new(args[:rotation])
    end

    def volumes
      @volumes ||= begin
        volumes = {}
        aws.snapshots.each do |snapshot|
          _snapshot = Snapshot.new(snapshot)
          volumes[_snapshot.volume_id] ||= []
          volumes[_snapshot.volume_id].push(_snapshot)
        end
        volumes
      end
    end

    def volume(volume_id)
      volumes[volume_id]
    end

    def describe
      puts rotation
      volumes.keys.each { |volume_id| describe_volume(volume_id) }
    end

    def prune
      volumes.keys.each { |volume_id| prune_volume(volume_id) }
    end

    def describe_volume(volume_id)
      analyzer = SnapshotAnalyzer.new(volume(volume_id), rotation)
      puts "VOLUME: #{volume_id}"
      analyzer.to_skip.each {|snapshot| puts   "  SKIP: #{snapshot.snapshot_id} : #{snapshot.date}"}
      analyzer.to_save.each {|snapshot| puts   "  KEEP: #{snapshot.snapshot_id} : #{snapshot.date}"}
      analyzer.to_delete.each {|snapshot| puts "  DELE: #{snapshot.snapshot_id} : #{snapshot.date}"}
    end

    def prune_volume(volume_id)
      analyzer = SnapshotAnalyzer.new(volume(volume_id), rotation)
      analyzer.to_delete.each { |snapshot| aws.delete(snapshot) }
    end

  end


  class Aws

    attr_reader :access_key, :secret_key

    def initialize(args={})
      args ||= {}
      @access_key = args[:access_key] || ENV['AMAZON_ACCESS_KEY_ID']
      @secret_key = args[:secret_key] || ENV['AMAZON_SECRET_ACCESS_KEY']
    end

    def connection
      @aws ||= ::AWS::EC2::Base.new(
        :access_key_id => access_key, :secret_access_key => secret_key
      )
    end

    def snapshots
      snapshots = connection.describe_snapshots(:owner => 'self')['snapshotSet']
      snapshots ? snapshots["item"] : []
    end

    def delete(snapshot)
      connection.delete_snapshot(:snapshot_id => snapshot.snapshot_id)
    end

  end

  class SnapshotAnalyzer

    attr_reader :snapshots, :rotation, :to_skip

    def initialize(snapshots, rotation)
      @snapshots = snapshots.sort
      @rotation  = rotation
      @to_skip   = []
      @to_delete = []
      @to_save   = {}
      analyze_snapshots
    end

    def to_save
      @to_save.empty? ? [snapshots[-1]] : @to_save.values
    end

    def to_delete
      snapshots - to_save - to_skip
    end

    def now
      @now ||= Time.now.utc
    end

    protected

    def save_newest_snapshot(snapshot, day)
      @to_save[day_key(day)] = snapshot
    end

    def save_oldest_snapshot(snapshot, day)
      @to_save[day_key(day)] ||= snapshot
    end

    def skip_snapshot(snapshot)
      @to_skip.push(snapshot) unless @to_skip.include?(snapshot)
    end

    def analyze_snapshots
      snapshots.each do |snapshot|
        if snapshot.completed?
          prune_daily(snapshot) || prune_weekly(snapshot) || prune_monthly(snapshot)
        else
          skip_snapshot(snapshot)
        end
      end
      to_save.sort!
      to_skip.sort!
      to_delete.sort!
    end

    ## Save newest snapshot on a day
    def prune_daily(snapshot)
      catch :found do
        (0..rotation.daily - 1).each do |count|
          day = in_days(count)
          if day_key(snapshot.created_at) == day_key(day)
            save_newest_snapshot(snapshot, day)
            throw :found, true
          end
        end
        false
      end
    end

    ## Save oldest snapshot on a week
    def prune_weekly(snapshot)
      catch :found do
        (0..rotation.weekly - 1).each do |count|
          week_beg = beginning_of_week(in_weeks(count))
          week_end = end_of_week(in_weeks(count))
          if snapshot.created_at >= week_beg && snapshot.created_at <= week_end
            save_oldest_snapshot(snapshot, week_beg)
            throw :found, true
          end
        end
        false
      end
    end

    ## Save oldest snapshot of every 4 weeks
    def prune_monthly(snapshot)
      catch :found do
        (0..rotation.monthly - 1).each do |count|
          month_beg = beginning_of_week(in_months(count))
          month_end = end_of_week(in_months(count))
          if snapshot.created_at >= month_beg && snapshot.created_at <= month_end
            save_oldest_snapshot(snapshot, month_beg)
            throw :found, true
          end
        end
        false
      end
    end

    def in_months(months)
      in_weeks(months * 4)
    end

    def in_weeks(weeks)
      in_days(weeks * 7)
    end

    def in_days(days)
      now - (86400 * days)
    end

    def beginning_of_week(date)
      days_from_sunday = date.wday
      bow = (date - (86400 * days_from_sunday))
      Time.utc(bow.year, bow.month, bow.day, 0, 0, 0)
    end

    def end_of_week(date)
      days_till_saturday = (6 - date.wday)
      eow = (date + (86400 * days_till_saturday))
      Time.utc(eow.year, eow.month, eow.day, 23, 59, 59)
    end

    def day_key(day)
      day.strftime("%Y%m%d")
    end

  end

  class Snapshot

    attr_reader :snapshot_id, :volume_id, :status, :created_at

    def initialize(params={})
      @snapshot_id = params['snapshotId']
      @volume_id   = params['volumeId']
      @status      = params['status']
      @created_at  = Time.parse(params['startTime']).utc
    end

    def completed?
      status == 'completed'
    end

    def <=>(other)
      created_at <=> other.created_at
    end

    def date
      created_at.strftime("%Y%m%d")
    end

  end

  class Rotation

    attr_reader :daily, :weekly, :monthly

    def initialize(args={})
      @daily   = args[:daily] ? args[:daily].to_i : 7
      @weekly  = args[:weekly] ? args[:weekly].to_i : 12
      @monthly = args[:monthly] ? args[:monthly].to_i : 14
    end

    def to_s
      "Rotation: Daily #{daily}, Weekly #{weekly}, Monthly #{monthly}"
    end

  end

end
