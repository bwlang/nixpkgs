{ lib, stdenv, fetchurl, ncurses, pkg-config, texinfo, libxml2, gnutls, gettext, autoconf, automake, jansson
, AppKit, Carbon, Cocoa, IOKit, OSAKit, Quartz, QuartzCore, WebKit
, ImageCaptureCore, GSS, ImageIO # These may be optional
}:

stdenv.mkDerivation rec {
  pname = "emacs";
  version = "28.1";

  emacsName = "emacs-${version}";
  macportVersion = "9.0";
  name = "emacs-mac-${version}-${macportVersion}";

  src = fetchurl {
    url = "mirror://gnu/emacs/${emacsName}.tar.xz";
    sha256 = "1qbmmmhnjhn4lvzsnyk7l5ganbi6wzbm38jc1a7hhyh3k78b7c98";
  };

  macportSrc = fetchurl {
    url = "ftp://ftp.math.s.chiba-u.ac.jp/emacs/${emacsName}-mac-${macportVersion}.tar.gz";
    sha256 = "10gyynz8wblz6r6dkk12m98kjbsmdwcbrhxpmsjylmdqmjxhlj4m";
    name = "${emacsName}-mac-${macportVersion}.tar.xz"; # It's actually compressed with xz, not gz
  };

  hiresSrc = fetchurl {
    url = "ftp://ftp.math.s.chiba-u.ac.jp/emacs/emacs-hires-icons-3.0.tar.gz";
    sha256 = "0f2wzdw2a3ac581322b2y79rlj3c9f33ddrq9allj97r1si6v5xk";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [ pkg-config autoconf automake ];

  buildInputs = [ ncurses libxml2 gnutls texinfo gettext jansson
    AppKit Carbon Cocoa IOKit OSAKit Quartz QuartzCore WebKit
    ImageCaptureCore GSS ImageIO   # may be optional
  ];

  postUnpack = ''
    mv $sourceRoot $name
    tar xf $macportSrc -C $name --strip-components=1
    mv $name $sourceRoot

    # extract retina image resources
    tar xfv $hiresSrc --strip 1 -C $sourceRoot
  '';

  postPatch = ''
    patch -p1 < patch-mac
    substituteInPlace lisp/international/mule-cmds.el \
      --replace /usr/share/locale ${gettext}/share/locale

    # use newer emacs icon
    cp nextstep/Cocoa/Emacs.base/Contents/Resources/Emacs.icns mac/Emacs.app/Contents/Resources/Emacs.icns

    # Fix sandbox impurities.
    substituteInPlace Makefile.in --replace '/bin/pwd' 'pwd'
    substituteInPlace lib-src/Makefile.in --replace '/bin/pwd' 'pwd'

    # Reduce closure size by cleaning the environment of the emacs dumper
    substituteInPlace src/Makefile.in \
      --replace 'RUN_TEMACS = ./temacs' 'RUN_TEMACS = env -i ./temacs'
  '';

  configureFlags = [
    "LDFLAGS=-L${ncurses.out}/lib"
    "--with-xml2=yes"
    "--with-gnutls=yes"
    "--with-mac"
    "--with-modules"
    "--enable-mac-app=$$out/Applications"
  ];

  CFLAGS = "-O3";
  LDFLAGS = "-O3 -L${ncurses.out}/lib";

  postInstall = ''
    mkdir -p $out/share/emacs/site-lisp/
    cp ${./site-start.el} $out/share/emacs/site-lisp/site-start.el
  '';

  # fails with:

  # Ran 3870 tests, 3759 results as expected, 6 unexpected, 105 skipped
  # 5 files contained unexpected results:
  #   lisp/url/url-handlers-test.log
  #   lisp/simple-tests.log
  #   lisp/files-x-tests.log
  #   lisp/cedet/srecode-utest-template.log
  #   lisp/net/tramp-tests.log
  doCheck = false;

  meta = with lib; {
    description = "The extensible, customizable text editor";
    homepage    = "https://www.gnu.org/software/emacs/";
    license     = licenses.gpl3Plus;
    maintainers = with maintainers; [ jwiegley matthewbauer ];
    platforms   = platforms.darwin;

    longDescription = ''
      GNU Emacs is an extensible, customizable text editor—and more.  At its
      core is an interpreter for Emacs Lisp, a dialect of the Lisp
      programming language with extensions to support text editing.

      The features of GNU Emacs include: content-sensitive editing modes,
      including syntax coloring, for a wide variety of file types including
      plain text, source code, and HTML; complete built-in documentation,
      including a tutorial for new users; full Unicode support for nearly all
      human languages and their scripts; highly customizable, using Emacs
      Lisp code or a graphical interface; a large number of extensions that
      add other functionality, including a project planner, mail and news
      reader, debugger interface, calendar, and more.  Many of these
      extensions are distributed with GNU Emacs; others are available
      separately.

      This is the "Mac port" addition to GNU Emacs. This provides a native
      GUI support for Mac OS X 10.6 - 10.12. Note that Emacs 23 and later
      already contain the official GUI support via the NS (Cocoa) port for
      Mac OS X 10.4 and later. So if it is good enough for you, then you
      don't need to try this.
    '';
  };
}
