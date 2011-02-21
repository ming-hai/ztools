#! /bin/perl
#
#   xml2wd.pl - Convert docbook XML to Wikidot syntax
#   Part of the ztools/apisite toolkit.
#
#   Author: Pieter Hintjens <ph@imatix.com>
#   License: public domain
#
#   This is a very hacky tool that turns a docbook XML file into Wikidot
#   content ready for upload via the Wikidot API. It would be better to
#   do this conversion using an XML stylesheet but I'm too lazy for that.
#
#   syntax: perl xml2wd.pl < inputfile > outputfile
#
#   Supply the Wikidot page category as an environment variable CATEGORY.

$category = $ENV{'CATEGORY'} || "page";

while (<>) {
    $output = "";
    s/\[/@@[@@/g;
    s/\]/@@]@@/g;

    $title = $1 if (/<refentrytitle>(.*)<\/refentrytitle>/);
    $volume = $1 if (/<manvolnum>(.*)<\/manvolnum>/);
    $source = $1 if (/<refmiscinfo class="source">(.*)<\/refmiscinfo>/);
    $version = $1 if (/<refmiscinfo class="version">(.*)<\/refmiscinfo>/);
    $manual = $1 if (/<refmiscinfo class="manual">(.*)<\/refmiscinfo>/);
    $name = $1 if (/<refname>(.*)<\/refname>/);
    $purpose = $1 if (/<refpurpose>(.*)<\/refpurpose>/);
    if (/<\/refmeta>/) {
        $output = <<"END";
[[include :csi:include:css-brackets]]
[[div style="width:30%; float:left;"]]
$title($volume)
[[/div]]
[[div style="width:40%; float:left;; text-align:center"]]
[/$category:_start Back to Contents]
[[/div]]
[[div style="width:30%; float:left; text-align:right"]]
$manual - $source/$version
[[/div]]
END
        if ($title eq "zmq") {
            open (TOC, ">_start.wd");
            print TOC "[[image http://api.zero.mq/local--files/admin:css/logo.gif]]\n\n";
            print TOC "++ ØMQ/$version API Reference\n\n";
            print TOC "[/master:_start Master] | [/2-1-0:_start v2.1.0] | [/2-0-10:_start v2.0.10] | [/2-0-9:_start v2.0.9] | [/2-0-8:_start v2.0.8] | [/2-0-7:_start v2.0.7] | [/2-0-6:_start v2.0.6]\n\n";
            close (TOC);
        }
    }
    elsif (/<\/refnamediv>/) {
        $output = <<"END";

++ Name

$name - $purpose
END
        open (TOC, ">>_start.wd");
        print TOC "* [/$category:$name $name] - $purpose\n";
        close (TOC);
    }
    if (/<refsynopsisdiv id="_synopsis">/) {
        $output = "\n++ Synopsis\n\n[[div class=\"synopsis\"]]";
    }
    if (/<\/refsynopsisdiv>/) {
        $output = "[[/div]]\n";
    }
    elsif (/<refsect1/) {
        $header = "++";
    }
    elsif (/<refsect2/) {
        $header = "+++";
    }
    elsif (/<refsect3/) {
        $header = "++++";
    }
    if (/<table.*<title>(.*)<\/title>/) {
        $output = "\n||||~ $1 ||\n";
    }
    elsif (/<entry>/) {
        $_ = load_tag ("entry");
        $output = "|| $_";
    }
    elsif (/<\/row>/) {
        $output = "||\n";
    }
    elsif (/<formalpara>/) {
        $_ = load_tag ("formalpara");
        if (/<title>(.*)<\/title><para>\s*(.*)<\/para>/s) {
            $output = "\n**". title_case ($1) ."**\n\n$2\n";
        }
    }
    elsif (/<title>(.*)<\/title>/) {
        $output = "\n$header ". title_case ($1) ."\n";
    }
    elsif (/<simpara>/) {
        $_ = load_tag ("simpara");
        $output = "\n$_\n";
    }
    elsif (/<literallayout>/) {
        $_ = load_tag ("literallayout");
        $output = "\n> {{$_}}\n";
    }
    elsif (/<literallayout class="monospaced">/) {
        $_ = $';
        chop while /\s$/;
        $line = $_;
        while (<>) {
            chop while /\s$/;
            $line .= "\n$_";
            if ($line =~ /(.*)<\/literallayout>/s) {
                $_ = $1;
                last;
            }
        }
        $output = "\n[[code]]\n$_\n[[/code]]\n";
    }

    if (/<term>/) {
        $_ = load_tag ("term");
        $output = "\n$_\n";
    }
    if (/<listitem>/) {
        $_ = load_tag ("listitem");
        #print "---- $_\n";
        #   Sometimes tables end up inside list items
        s/<informal.*?<tbody valign="top">/\n/s;
        s/\s*<\/tbody><\/tgroup><\/informaltable>//s;
        while (/\s*<entry>\s*(.*?)\s*<\/entry>\s*/s) {
            $_ = $` . "$1 ||" . $';
        }
        while (/\s*<row>\s*(.*?)\s*<\/row>/) {
            $_ = $` . "\n|| $1\n" . $';
        }
        $output = "* $_\n";
    }

    #   General substitutions
    $output =~ s/\/\//@@\/\/@@/g;
    $output =~ s/\\\/\\\//\/\//g;   #   // in code blocks was escaped

    $output =~ s/0MQ/ØMQ/g;
    $output =~ s/<emphasis>([^<]*)<\/emphasis>/\/\/$1\/\//g;
    $output =~ s/<emphasis role="strong">([^<]*)<\/emphasis>/**$1**/g;
    $output =~ s/<literal>([^<]*)<\/literal>/{{$1}}/g;
    $output =~ s/<manvolnum>([^<]*)<\/manvo>/{{$1}}/g;
    $output =~ s/<citerefentry>\s*<refentrytitle>([^<]*)<\/refentrytitle><manvolnum>([^<]*)<\/manvolnum>\s*<\/citerefentry>/\[\/$category:$1 $1($2)\]/g;
    $output =~ s/<ulink url="[^"]*">([^<]*)<\/ulink>/$1/g;
    $output =~ s/<simpara>([^<]*)<\/simpara>/$1/g;
    $output =~ s/&lt;/</g;
    $output =~ s/&gt;/>/g;
    $output =~ s/&amp;/&/g;
    $output =~ s/&#8217;/'/g;
    $output =~ s/&#8230;/.../g;

    print $output if $output;
}


sub load_tag {
    local ($tag) = @_;
    if (/<$tag>(.*)<\/$tag>/) {
        return $1;
    }
    else {
        chop while /\s$/;
        /<$tag>/;
        $line = $';
        while (<>) {
            chop while /\s$/;
            if (/<screen>/) {
                $_ = "[[code]]\n$'";
                s/\/\//\\\/\\\//g;
                $code = 1;
            }
            elsif (/<\/screen>/) {
                $_ = "$`\n[[/code]]";
                s/\/\//\\\/\\\//g;
                $code = 0;
            }
            if ($code) {
                s/\/\//\\\/\\\//g;
                $line .= "\n$_";
            }
            else {
                $line .= " " if $line;
                $line .= $_;
            }
            if ($line =~ /(.*)<\/$tag>/s) {
                return $1;
                last;
            }
        }
    }
}

sub title_case {
    local ($_) = @_;
    if (!/^ZMQ_/) {
        tr/[A-Z]/[a-z]/;
        s/(\w+)/\u\L$1/;
        s/Zmq_/zmq_/g;
    }
    return $_;
}