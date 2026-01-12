# Automatically resizes the given filesystem.
class Tasks::AutoResize < Task
  attr_reader :device

  def initialize(device, type: )
    @device = device
    @type = type
    add_dependency(:Devices, @device)
    add_dependency(:Mount, "/sys")
    # For better user experience.
    # Otherwise the device may look like it's hanging.
    add_dependency(:Target, :Graphics)
  end

  # Computes whether a filesystem needs to be expanded.
  # This way the long-running tasks happen only once.
  # TODO: parse more than ext filesystems
  def needs_resize?()
    # Parse the output of dumpe2fs
    data = `dumpe2fs -h #{@device.shellescape}`
      .lines
      .map(&:strip)
      .map { |line| line.split(/:\s*/, 2) }
      .select { |pair| pair.length == 2 }
      .to_h

    block_size = data["Block size"].to_f
    block_count = data["Block count"].to_f

    # In bytes
    filesystem_size = block_count * block_size

    device_file = File.realpath(@device)
    sys_file = Dir.glob("/sys/block/*/#{device_file.split("/").last}").first

    # In bytes. From 512 bytes sectors.
    partition_size = 512 * File.read(File.join(sys_file, "size")).to_f

    # Accounts for a partition size that can't fit a full block, plus some
    # fudge. It's been found that on some "fully resized" devices there was
    # more than the block size left at the end.
    fudge = 2 * block_size

    # Output the sizes in the log, for later interpretations.
    log("#{@device}: #{filesystem_size}/#{partition_size} in use.")

    # Resize when the filesystem size is smaller than the available space.
    # (While accounting for some fudge.)
    filesystem_size < (partition_size - fudge)
  end

  def run()
    if @type.match(/^ext[234]$/)
      if needs_resize?
        log("Resizing #{@device}...")
        Progress.exec_with_message("Verifying #{@device}...") do
          # e2fsck exit codes:
          # 0 = No errors
          # 1 = Filesystem errors corrected
          # 2 = Filesystem errors corrected, system should be rebooted
          # 4+ = Actual errors that couldn't be corrected
          # We use -fy instead of -fp:
          # -f = Force checking even if filesystem seems clean
          # -y = Automatically answer yes to all prompts (more aggressive than -p)
          # -p (preen) is too conservative and returns exit code 4 for issues it won't auto-fix
          pid = System.spawn("e2fsck", "-fy", @device)
          ret = nil

          loop do
            Progress.send_state()
            break if ret = Process.wait(pid, Process::WNOHANG)
            sleep(0.1)
          end

          status = $?.exitstatus
          if status == 127
            raise System::CommandNotFound.new("Command not found... e2fsck (#{status})")
          elsif status > 2
            raise System::CommandError.new("e2fsck failed with errors (exit code #{status})")
          else
            $logger.info("e2fsck completed successfully (exit code #{status})")
          end
        end
        Progress.exec_with_message("Resizing #{@device}...") do
          System.run_long_running("resize2fs", "-f", @device)
        end
      else
        log("No need to resize #{@device}...")
      end
    else
      $logger.warn("Cannot resize #{@type}... filesystem left untouched.")
    end
  end
end
