class Fail2ban < Formula
  desc "Scan log files and ban IPs showing malicious signs"
  homepage "https://www.fail2ban.org/"
  url "https://github.com/fail2ban/fail2ban/archive/1.0.2.tar.gz"
  sha256 "ae8b0b41f27a7be12d40488789d6c258029b23a01168e3c0d347ee80b325ac23"
  license "GPL-2.0-or-later"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "dc259b593012eeded9d953d683689ca4ca600b90f47afc578e0838fc17a7a5df"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "dc259b593012eeded9d953d683689ca4ca600b90f47afc578e0838fc17a7a5df"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "dc259b593012eeded9d953d683689ca4ca600b90f47afc578e0838fc17a7a5df"
    sha256 cellar: :any_skip_relocation, monterey:       "05c91cca152e3cf66cd78faacdc60ddd0326798c8ea1d2995400e34f564d9061"
    sha256 cellar: :any_skip_relocation, big_sur:        "05c91cca152e3cf66cd78faacdc60ddd0326798c8ea1d2995400e34f564d9061"
    sha256 cellar: :any_skip_relocation, catalina:       "05c91cca152e3cf66cd78faacdc60ddd0326798c8ea1d2995400e34f564d9061"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "e369190e3f6a19f0a19115ece5bc7bcb6c6482b053fd9bc3757ae8222e650cf1"
  end

  depends_on "help2man" => :build
  depends_on "sphinx-doc" => :build
  depends_on "python@3.10"

  def install
    python3 = "python3.10"
    ENV["PYTHON"] = which(python3)

    rm "setup.cfg"
    Pathname.glob("config/paths-*.conf").reject do |pn|
      pn.fnmatch?("config/paths-common.conf") || pn.fnmatch?("config/paths-osx.conf")
    end.map(&:unlink)

    # Replace paths in config
    inreplace "config/jail.conf", "before = paths-debian.conf", "before = paths-osx.conf"

    # Replace hardcoded paths
    inreplace_etc_var("setup.py")
    inreplace_etc_var(Pathname.glob("config/{action,filter}.d/**/*").select(&:file?), audit_result: false)
    inreplace_etc_var(["config/fail2ban.conf", "config/paths-common.conf", "doc/run-rootless.txt"])
    inreplace_etc_var(Pathname.glob("fail2ban/client/*"), audit_result: false)

    inreplace "fail2ban/server/asyncserver.py", "/var/run/fail2ban/fail2ban.sock",
              var/"run/fail2ban/fail2ban.sock"

    inreplace_etc_var(Pathname.glob("fail2ban/tests/**/*").select(&:file?), audit_result: false)
    inreplace_etc_var(Pathname.glob("man/*"), audit_result: false)

    # Fix doc compilation
    inreplace "setup.py", "/usr/share/doc/fail2ban", doc
    inreplace "setup.py", "if os.path.exists('#{var}/run')", "if True"
    inreplace "setup.py", "platform_system in ('linux',", "platform_system in ('linux', 'darwin',"

    system "./fail2ban-2to3"
    system python3, *Language::Python.setup_install_args(prefix, python3), "--without-tests"

    cd "doc" do
      system "make", "dirhtml", "SPHINXBUILD=sphinx-build"
      doc.install "build/dirhtml"
    end

    man1.install Pathname.glob("man/*.1")
    man5.install "man/jail.conf.5"
  end

  def inreplace_etc_var(targets, audit_result: true)
    inreplace targets do |s|
      s.gsub! %r{/etc}, etc, audit_result
      s.gsub! %r{/var}, var, audit_result
    end
  end

  def post_install
    (etc/"fail2ban").mkpath
    (var/"run/fail2ban").mkpath
  end

  def caveats
    <<~EOS
      Before using Fail2Ban for the first time you should edit the jail
      configuration and enable the jails that you want to use, for instance
      ssh-ipfw. Also, make sure that they point to the correct configuration
      path. I.e. on Mountain Lion the sshd logfile should point to
      /var/log/system.log.

        * #{etc}/fail2ban/jail.conf

      The Fail2Ban wiki has two pages with instructions for macOS Server that
      describes how to set up the Jails for the standard macOS Server
      services for the respective releases.

        10.4: https://www.fail2ban.org/wiki/index.php/HOWTO_Mac_OS_X_Server_(10.4)
        10.5: https://www.fail2ban.org/wiki/index.php/HOWTO_Mac_OS_X_Server_(10.5)

      Please do not forget to update your configuration files.
      They are in #{etc}/fail2ban.
    EOS
  end

  plist_options startup: true

  service do
    run [opt_bin/"fail2ban-client", "-x", "start"]
  end

  test do
    system "#{bin}/fail2ban-client", "--test"

    (testpath/"test.log").write <<~EOS
      Jan 31 11:59:59 [sshd] error: PAM: Authentication failure for test from 127.0.0.1
    EOS
    system "#{bin}/fail2ban-regex", "test.log", "sshd"
  end
end
