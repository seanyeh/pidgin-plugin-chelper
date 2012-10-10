# chelper.pl
#
# Plugin for libpurple with a couple options to help users read Chinese
# characters in incoming messages. Can provide hanyu pinyin for Chinese
# characters, as well as translate simplified characters to traditional (or
# vice versa).

# License: MIT License

# Copyright (c) 2011 Sean Yeh

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use Purple;
use MIME::Base64;
use utf8;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "Chinese helper",
    version => "0.1",
    summary => "Options to provide hanyu pinyin for Chinese characters. Can also
    translate simplified characters to traditional (and vice versa).",
    description => "Some options to help with the Chinese language.",
    author => "Sean Yeh",
    url => "",
    load => "plugin_load",
    unload => "plugin_unload",
    prefs_info => "prefs_info_cb"
);


my @dict;

sub plugin_init {
    return %PLUGIN_INFO;
}

sub plugin_load {
    $plugin = shift;

    Purple::Debug::info("chelper", "plugin_load() - begin\n");

    # Preferences
    Purple::Prefs::add_none("/plugins/core/chelper");
    Purple::Prefs::add_int("/plugins/core/chelper/convert", "None");

    Purple::Prefs::add_bool("/plugins/core/chelper/pinyin", 1);
    Purple::Prefs::add_bool("/plugins/core/chelper/show_all_pinyin", 1);
    Purple::Prefs::add_bool("/plugins/core/chelper/show_original", 0);

    # A pointer to the handle to which the signal belongs
    $convs_handle = Purple::Conversations::get_handle();

    # Connect the perl sub 'receiving_im_msg_cb' to the event 'receiving-im-msg'
    Purple::Signal::connect($convs_handle, "receiving-im-msg", $plugin, \&receiving_im_msg_cb, "yyy");

    Purple::Debug::info("chelper", "plugin_load() - chelper plugin loaded\n");

    # read dictionary file
    open (DICT_FILE, '<:encoding(UTF-8)', Purple::Util::user_dir()."/plugins/chelper/cedict_ts.u8");

    while(<DICT_FILE>){
        my $line = $_;
        if ( substr($line,0,1) ne "#" ){
            my @temp1 = split( / \[*/, $_, 3 );
            my @temp2 = split( "] ", $temp1[2] );
            my @a = ( $temp1[0], $temp1[1], $temp2[0], $temp2[1] ); 
            push( @dict, [@a] );
        }
    }
}

sub plugin_unload {
    my $plugin = shift;
    Purple::Debug::info("chelper", "plugin_unload() - chelper plugin unloaded.\n");
}

# Given char, return char[pinyin], or just char if not found
sub get_pinyin {
    my $char = $_[0];

    my $convert_pref = Purple::Prefs::get_int("/plugins/core/chelper/convert");

    my $msg = "";

    for (my $i = 0; $i < $#dict; $i++ ){
        @line = @{@dict[$i]};

        if ( $char eq $line[0] || $char eq $line[1] ){
            print "found line: $line[0], $line[1], $line[2], $line[3]\n";

            # If first time, add character
            if ( $msg eq "" ){

                my $new_char = $char;

                # if traditional
                if ( $convert_pref == 1 ){
                    print "convert to traditional! $line[0]\n";
                    $new_char = $line[0];
                }
                # if simplified
                if ( $convert_pref == 2 ){
                    print "convert to simplfied! $line[1]\n";
                    $new_char = $line[1];
                }

                $msg .= $new_char."[";
            }

            # Add pinyin
            $msg .= $line[2].",";
            print "Adding to msg. now msg = $msg\n";

            # if only looking for the first, break
            if (!Purple::Prefs::get_bool("/plugins/core/chelper/show_all_pinyin")){
                last;
            }
        }
    }

    # if not found
    if ( $msg eq "" ){
        return $char;
    } else{
        chop($msg);
        print "Done! msg: $msg]\n";
        return $msg."]";
    }
}

sub is_chinese {
    my $unicode = $_[0];
    if ( ($unicode >= 13312 && $unicode <= 40959) ||
        ($unicode >= 131072 && $unicode <= 173791) ||
        ($unicode >= 63744 && $unicode <= 64255) ||
        ($unicode >= 194560 && $unicode <= 195103) ){
        return 1;
    }
    return 0;
}

sub receiving_im_msg_cb {
    my ($account, $who, $msg, $conv, $flags) = @_;

    # Return immediately if pinyin is disabled
    if(!Purple::Prefs::get_bool("/plugins/core/chelper/pinyin")){
        return;
    }

    my $new_msg = "";

    @unicode_arr = unpack 'U*', $msg;
    for (my $i=0; $i < length($msg); $i++){
        $char = substr($msg, $i, 1);
        print "char: $char\n";

        my $unicode = int($unicode_arr[$i]);
        if ( is_chinese($unicode) ){
            $new_msg .= get_pinyin($char);  
            print "Done adding new pinyin\n";
        } else{
            $new_msg .= $char;
        }
    }

    print "new msg: $new_msg\n";

    if (Purple::Prefs::get_bool("/plugins/core/chelper/show_original") &&
        $msg ne $new_msg ){
        $new_msg = "Original: ".$msg." | ".$new_msg;
    }
    $_[2] = $new_msg;

}

sub prefs_info_cb {
    $frame = Purple::PluginPref::Frame->new();

    # Pinyin preference
    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/chelper/pinyin", "Enable pinyin");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/chelper/show_all_pinyin", "Show all pronunciations 
        (pinyin must be enabled)");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/chelper/show_original", "Show original message 
        (pinyin must be enabled)");
    $frame->add($ppref);

    # Convert preference
    $ppref = Purple::PluginPref->new_with_name_and_label(
        "/plugins/core/chelper/convert", "Convert Simplfied <==> Traditional");
    $ppref->set_type(1); # To indicate a drop-down choice
    $ppref->add_choice("None", 0);
    $ppref->add_choice("Convert simplified characters to traditional", 1);
    $ppref->add_choice("Convert traditional characters to simplified", 2);
    $frame->add($ppref);

    return $frame;
}
