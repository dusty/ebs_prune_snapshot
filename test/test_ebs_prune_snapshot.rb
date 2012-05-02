#!/usr/bin/env ruby

#require 'time'
require 'ebs_prune_snapshot'
require 'minitest/autorun'

##
# Generates snapshots that simulate amazon-ec describe snapshots
# - 400 daily completed snapshots for 2 different volumes
# - 1 daily pending snapshot for 2 volumes
# - 1 really old single snapshot for a 3rd volume
module EbsPruneSnapshot
  class Tester

    def self.snapshots
      @snapshots ||= new.snapshots
    end

    def self.now
      Time.utc(2012,5,1)
    end

    def generate_snapshot(snapshot_id, volume_id, start_time)
      {
        "snapshotId" => snapshot_id,
        "volumeId" => volume_id,
        "status" => 'completed',
        "startTime" => start_time.xmlschema,
        "progress" => '100%',
        "ownerId" => '00000000',
        "volumeSize" => '1',
        "description" => "test #{snapshot_id}"
      }
    end

    def initialize
      @volumes  = ['vol-000000', 'vol-000001']
      @now      = Tester.now
      @days     = 400
    end

    def snapshots
      @items ||= begin
        items = []
        count = 0
        # generate snapshots for each day for the previous 400 days for each volume
        @volumes[0..1].each do |volume_id|
          (0..@days - 1).each do |day|
            snapshot_id = "%06d" % count
            start_time  = @now - (86400 * day)
            items << generate_snapshot(snapshot_id, volume_id, start_time)
            count += 1
          end
        end
        # add pending snapshots
        items << generate_snapshot("111111", @volumes[0], @now - 86400).update("status" => "pending")
        items << generate_snapshot("222222", @volumes[1], @now - 86400).update("status" => "pending")

        # add 2 really old snapshots under another volume
        items << generate_snapshot("333333", @volumes[3], @now - 86400 * 7 * 60)
        items << generate_snapshot("444444", @volumes[3], @now - 86400 * 7 * 90)
      end
    end

    # Starting on 5/1/12, assuming a snapshot taken every day, with a 7/12/13 rotation
    def self.expectations
      day = [
        Time.utc(2012,5,1), Time.utc(2012,4,30), Time.utc(2012,4,29), Time.utc(2012,4,28), Time.utc(2012,4,27),
        Time.utc(2012,4,26), Time.utc(2012,4,25)
      ]
      week = [
        Time.utc(2012,4,29), Time.utc(2012,4,22), Time.utc(2012,4,15), Time.utc(2012,4,8), Time.utc(2012,4,1),
        Time.utc(2012,3,25), Time.utc(2012,3,18), Time.utc(2012,3,11), Time.utc(2012,3,4), Time.utc(2012,2,26),
        Time.utc(2012,2,19), Time.utc(2012,2,12)
      ]
      month = [
        Time.utc(2012,4,29), Time.utc(2012,4,1), Time.utc(2012,3,4), Time.utc(2012,2,5), Time.utc(2012,1,8),
        Time.utc(2011,12,11), Time.utc(2011,11,13), Time.utc(2011,10,16), Time.utc(2011,9,18), Time.utc(2011,8,21),
        Time.utc(2011,7,24), Time.utc(2011,6,26), Time.utc(2011,5,29), Time.utc(2011,5,1)
      ]
      (day + week + month).uniq.sort
    end
  end
end

##
# Stub snapshots
class EbsPruneSnapshot::Aws
  def snapshots
    EbsPruneSnapshot::Tester.snapshots
  end
  def delete(snapshot)
    puts "running delete on #{snapshot.snapshot_id}"
  end
end
class EbsPruneSnapshot::SnapshotAnalyzer
  def now
    EbsPruneSnapshot::Tester.now
  end
end


class TestEbsPruneSnapshot < MiniTest::Unit::TestCase
  def self.ebs
    @ebs ||= EbsPruneSnapshot::Base.new(:rotation => {:daily => 7, :weekly => 12, :monthly => 14})
  end

  def setup
    @ebs = self.class.ebs
  end

  def self.now
    Time.utc(2012,5,1)
  end

  def in_days(days)
    self.class.now - (86400 * days)
  end

  def test_sort_by_volume
    assert_equal self.class.ebs.volumes.count, 3
  end

  def test_volume_analyzer
    vol1 = @ebs.volumes[@ebs.volumes.keys[0]]
    vol2 = @ebs.volumes[@ebs.volumes.keys[1]]
    [vol1, vol2].each do |snapshots|
      analyzer = EbsPruneSnapshot::SnapshotAnalyzer.new(snapshots, @ebs.rotation)
      assert_equal analyzer.to_save.count, 29
      assert_equal analyzer.to_skip.count, 1
      assert_equal analyzer.to_delete.count, 371
    end
  end

  def test_safety_mechanism
    snapshots = @ebs.volumes[@ebs.volumes.keys[2]]
    analyzer = EbsPruneSnapshot::SnapshotAnalyzer.new(snapshots, @ebs.rotation)
    assert_equal analyzer.to_save.count, 1
    assert_equal analyzer.to_skip.count, 0
    assert_equal analyzer.to_delete.count, 1
    assert_equal analyzer.to_save.first.snapshot_id, "333333"
  end

  def test_actual_expected_dates
    vol1 = @ebs.volumes[@ebs.volumes.keys[0]]
    vol2 = @ebs.volumes[@ebs.volumes.keys[1]]
    [vol1, vol2].each do |snapshots|
      analyzer = EbsPruneSnapshot::SnapshotAnalyzer.new(snapshots, @ebs.rotation)
      assert_equal analyzer.to_save.map {|s| s.created_at} , EbsPruneSnapshot::Tester.expectations
    end
  end

  def test_describe
    skip
    @ebs.describe
  end

  def test_prune
    skip
    @ebs.prune
  end

end

