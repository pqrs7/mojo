package Mojolicious::Static;
use Mojo::Base -base;

use File::stat;
use File::Spec;
use Mojo::Asset::File;
use Mojo::Asset::Memory;
use Mojo::Command;
use Mojo::Content::Single;
use Mojo::Path;

has [qw/default_static_class root/];

# "Valentine's Day's coming? Aw crap! I forgot to get a girlfriend again!"
sub dispatch {
    my ($self, $c) = @_;

    # Already rendered
    return if $c->res->code;

    # Canonical path
    my $path = $c->req->url->path->clone->canonicalize->to_string;

    # Parts
    my @parts = @{Mojo::Path->new->parse($path)->parts};

    # Shortcut
    return 1 unless @parts;

    # Prevent directory traversal
    return 1 if $parts[0] eq '..';

    # Serve static file
    unless ($self->serve($c, join('/', @parts))) {

        # Rendered
        $c->stash->{'mojo.static'} = 1;
        $c->rendered;

        return;
    }

    return 1;
}

sub serve {
    my ($self, $c, $rel) = @_;

    # Append path to root
    my $path = File::Spec->catfile($self->root, split('/', $rel));

    # Extension
    $path =~ /\.(\w+)$/;
    my $ext = $1;

    # Type
    my $type = $c->app->types->type($ext) || 'text/plain';

    # Response
    my $res = $c->res;

    # Asset
    my $asset;

    # Modified
    my $modified = $self->{_modified} ||= time;

    # Size
    my $size = 0;

    # File
    if (-f $path) {

        # Readable
        if (-r $path) {

            # Modified
            my $stat = stat($path);
            $modified = $stat->mtime;

            # Size
            $size = $stat->size;

            # Content
            $asset = Mojo::Asset::File->new(path => $path);
        }

        # Exists, but is forbidden
        else {
            $c->app->log->debug(qq/File "$rel" forbidden./);
            $res->code(403) and return;
        }
    }

    # Inline file
    elsif (defined(my $file = $self->_get_inline_file($c, $rel))) {
        $size  = length $file;
        $asset = Mojo::Asset::Memory->new->add_chunk($file);
    }

    # Found
    if ($asset) {

        # Request
        my $req = $c->req;

        # Request headers
        my $rqh = $req->headers;

        # Response headers
        my $rsh = $res->headers;

        # If modified since
        if (my $date = $rqh->if_modified_since) {

            # Not modified
            my $since = Mojo::Date->new($date)->epoch;
            if (defined $since && $since == $modified) {
                $res->code(304);
                $rsh->remove('Content-Type');
                $rsh->remove('Content-Length');
                $rsh->remove('Content-Disposition');
                return;
            }
        }

        # Start and end
        my $start = 0;
        my $end = $size - 1 >= 0 ? $size - 1 : 0;

        # Range
        if (my $range = $rqh->range) {
            if ($range =~ m/^bytes=(\d+)\-(\d+)?/ && $1 <= $end) {
                $start = $1;
                $end = $2 if defined $2 && $2 <= $end;
                $res->code(206);
                $rsh->content_length($end - $start + 1);
                $rsh->content_range("bytes $start-$end/$size");
            }
            else {

                # Not satisfiable
                $res->code(416);
                return;
            }
        }
        $asset->start_range($start);
        $asset->end_range($end);

        # Response
        $res->code(200) unless $res->code;
        $res->content->asset($asset);
        $rsh->content_type($type);
        $rsh->accept_ranges('bytes');
        $rsh->last_modified(Mojo::Date->new($modified));
        return;
    }

    return 1;
}

sub _get_inline_file {
    my ($self, $c, $rel) = @_;

    # Protect templates
    return if $rel =~ /\.\w+\.\w+$/;

    # Class
    my $class =
         $c->stash->{static_class}
      || $ENV{MOJO_STATIC_CLASS}
      || $self->default_static_class
      || 'main';

    # Inline files
    my $inline = $self->{_inline_files}->{$class}
      ||= [keys %{Mojo::Command->new->get_all_data($class) || {}}];

    # Find inline file
    for my $path (@$inline) {
        return Mojo::Command->new->get_data($path, $class) if $path eq $rel;
    }

    # Bundled files
    my $bundled = $self->{_bundled_files}
      ||= [keys %{Mojo::Command->new->get_all_data(ref $self) || {}}];

    # Find bundled file
    for my $path (@$bundled) {
        return Mojo::Command->new->get_data($path, ref $self)
          if $path eq $rel;
    }

    # Nothing
    return;
}

1;
__DATA__

@@ amelia.png (base64)
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

@@ favicon.ico (base64)
AAABAAIAGBgAAAEAIAC4CQAAJgAAABAQAAABACAAaAQAAN4JAAAoAAAAGAAAADAAAAABACAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAA////AP///wD///8A////AP///wD///8A////AP///wD///8A
////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD/
//8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP//
/wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////APz8/AD5+fkA+fn5
APn5+QD5+fkA+fn5APn5+QD5+fkA+fn5Avn5+QP5+fkD+fn5Avn5+QD5+fkA+fn5APn5+QD5+fkA
+fn5APn5+QD5+fkA+fn5APz8/AD///8A////AP///wD///8A////A////wT///8D////BP///wP/
//8D////AP///wD///8A////AP///wP///8D////A////wT///8E////A////wH///8A////AP//
/wD///8A////AL+/vwF/f38EhISEAIODgwCEhIQAg4ODAIGBgQCDg4MAf39/EHd3dzN3d3c2fn5+
GIODgwCBgYEAgoKCAIODgwCDg4MAgoKCAICAgAKCgoIDf39/AL+/vwD///8A////AHBwcAIAAAAA
AAAAIwAAAGoAAACHAAAAZgAAAC8AAABYAAAArAoKCs8LCwvRAAAAtAAAAHEAAAAqAAAALwAAAEwA
AABGAAAAKQAAAAAAAAAAAAAABXFxcQD///8A////AoSEhAAHBwc6FhYWvlVVVf+BgYH/UVFR/A4O
Dss6Ojrtmpqa/8rKyv/Jycn/pKSk/1VVVf8aGhrHKSkpykdHR+hCQkLhHR0dxgAAAIcJCQkhBgYG
AIKCggL///8A////AX9/fxUAAACweHh4/+np6fn////63t7e/5qamv/Nzc3/////+v////r////5
////+ubm5v2urq7/u7u7/93d3f/W1tb/tbW1/11dXf8MDAy4AQEBJYGBgQD///8D////AHZ2djgI
CAjV2tra+/////bp6en/+/v7/f////r////88PDw/+rq6v/r6+v/7+/v//v7+/3////5////+f7+
/vv9/f37////+O7u7vhra2v/AAAAkoGBgQr///8C////AHx8fBoJCQm0mpqa//j4+Pry8vL+8fHx
//Hx8f/w8PD/9PT0//f39//29vb/9fX1//Hx8f/v7+//8PDw//Dw8P/w8PD/6enp//////jKysr8
DAwMz3h4eC3///8A////AISEhAcAAACiZGRk//r6+vr9/f3+9PT0//f39//4+Pj/+fj4//j4+P/3
9/f/9/f3//j4+P/4+Pj/+Pj4//j4+P/5+fn/8vLy//z8/PrX19f+FhYW2XNzcz7///8A////AHZ2
dkIYGBjhw8PD//////v5+fn/+vv7//v7+//7+vr/+/r6//r6+v/6+vr/+/v7//v7+//7+/v/+/v7
//v7+//6+vr/+Pj4//////mqqqr/BQUFvnx8fBr///8A////AGpqanJMTEz//////Pz8/P76+vr/
/P39//39/f/+/v7//v7+//7+/v/+/v7//v7+//7+/v/+/v7//v7+//7+/v/6+vr//v7+/NHR0f09
PT3uAAAAaIODgwD///8C////AGxsbGtAQED8+vr6+vn5+fz39/f+/v7+/v7/////////////////
///////////////////////////////////6+vr/////+8fHx/8vLy/sAAAAR4ODgwH///8F////
AHl5eTAPDw/br6+v//////T////6/f39+/n5+f79/f3///////////////////////39/f/6+vr/
+/v7//7+/v/+/v7/+/v7/v////x8fHz/AAAAeoSEhAD///8E////AYKCggAAAABfKCgo5I+Pj/+V
lZX/YWFh/8nJyf3////+9vb2//39/f/9/f3/+/v7//////7////8/////fn5+f/4+Pj/9/f3/f//
//l8fHz/AAAAfoWFhQD///8F////AX9/fwEBAQEBAAAASAAAAJoEBASTAAAAultbW//x8fH7////
+fv7+/77+/v//////Pr6+vq+vr7/5OTk/v////r////6////9bq6uv8oKCjsAAAAQoODgwD///8E
////AIKCggEGBgYBDw8PAAcHBwAICAgADAwMIg4ODrBsbGz/1NTU//////n////67Ozs/4eHh/8q
KirzWFhY/Kmpqf+6urr/lZWV/zMzM/ADAwNwBgYGCIKCggL///8B////AHFxcQAAAAACAAAABQAA
AAEAAAAFAAAAAAAAACIAAACUFBQU5klJSf9QUFD/LS0t+AAAALAAAABXAAAAbgAAAK0AAAC4AAAA
oAAAAFgAAAAHAAAAAHFxcQL///8A////AL+/vwB/f38AgoKCAH9/fwKAgIAEf39/BoGBgQCCgoIC
dXV1SWxsbHRqamp2b29vW35+fhuCgoIAgoKCAH5+fhF6enodgYGBA4KCggCCgoIAf39/Ab+/vwD/
//8A////AP///wD///8A////AP///wD///8A////AP///wL///8A////AP///wD///8A////AP//
/wD///8F////A////wD///8A////AP///wT///8B////AP///wD///8A////APz8/AD5+fkA+fn5
APn5+QD5+fkA+fn5APn5+QD5+fkB+fn5BPn5+Qb5+fkG+fn5Bfn5+QL5+fkA+fn5APn5+QL5+fkC
+fn5Afn5+QD5+fkA+fn5APz8/AD///8A////AP///wD///8A////AP///wD///8A////AP///wD/
//8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP//
/wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////
AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8AAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAKAAAABAAAAAgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
APn5+QD5+fkA+fn5Avn5+QP5+fkB+fn5Avn5+QT6+voE+fn5BPn5+QL5+fkB+fn5Afn5+QH5+fkA
+fn5APn5+QD///8B////A////wD///8A////AP///wD///8A////AP///wD///8A////Av///wD/
//8A////A////wL///8AgICAAIKCggB1dXUacXFxJH9/fwB5eXkUc3NzSXx8fFNxcXFFeXl5EH9/
fwB4eHgJeXl5BYKCggCDg4MAf39/AwAAAAAAAABpFBQUtyYmJsIAAACOAQEBp01NTeZiYmLuQkJC
4gAAAKUAAAB8BgYGngAAAJQAAABpAAAAFAAAAAAGBgZZYGBg+NTU1P/k5OT/m5ub/7q6uv//////
/////vz8/P+9vb3/oaGh/8bGxv+8vLz/hoaG+x0dHa4FBQUbAQEBjJ6env/////09fX19v////z/
///59vb29/Hx8fv39/f3////+f////3////5/////P////eSkpL/CAgIgQAAAFdPT0/+9/f3/O3t
7f/09PT+8PDw/vPz8//19fX/8vLy//Dw8P/w8PD98/Pz/uzs7P/8/Pz06+vr+x0dHb8KCgqfkpKS
//////z4+Pj/+/v7//38/P78/Pz++/v7/v39/f78/Pz++vr6//7+/v74+Pj//v7++Kqqqv8PDw+S
GRkZ9/v7+/n6+vr4+fn5+v7+/v/8/Pz//f39//7+/v/+/v7//f39/v39/f7+/v7//v7+//r6+vtB
QUH2AAAAPwkJCambm5v/////+//////8/Pz7+fn5//r6+v//////+/v7//z8/P/6+vr9+fn5//Ly
8v/29vb4d3d39AEBAUsAAAAjGBgYtoeHh/JnZ2fzl5eX//////n4+Pj8/Pz8//z8/Pz////7////
/P////j7+/v6////8ImJif8AAABbCQkJAAMDAxkAAABaAAAAVRoaGsO6urr/////+/////r////+
p6en/4iIiP/Z2dn/5OTk/62trf8fHx/ABwcHFwAAAAQAAAAAAAAAAAAAAAAAAAAqAAAArVFRUf5t
bW3/T09P/gAAAKYAAAB4GhoauSMjI8IAAACbAAAAKwAAAACAgIAAf39/BoGBgQd/f38KgoKCAHp6
ehJycnJjeXl5eHBwcGF8fHwTgYGBAHNzcx1xcXEofX19AIODgwB/f38C////AP///wD///8A////
AP///wP///8A////AP///wD///8A////AP///wP///8A////AP///wD///8D////APn5+QD5+fkA
+fn5APn5+QD5+fkA+fn5Avn5+QX6+voG+fn5Bfn5+QL5+fkA+fn5Avn5+QP5+fkB+fn5APn5+QAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAA

@@ mojolicious-arrow.png (base64)
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
RUAEQkbg/wHOM/O1uoRuOAAAAABJRU5ErkJggg==

@@ mojolicious-black.png (base64)
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
9QAAAABJRU5ErkJggg==

@@ mojolicious-box.png (base64)
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
QXvMyP8fDW803BGUoH4AAAAASUVORK5CYII=

@@ mojolicious-clouds.png (base64)
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
QmCC

@@ mojolicious-pinstripe.gif (base64)
R0lGODlhGAAMAJEAAA4ODhkZGQAAAAAAACH5BAkKAAIALAAAAAAYAAwAAAIjBGKJedzqFmTyzWuq
szl6zIWVRn4dZZ7qKqIuqKXtO8N0fRYAOw==

@@ mojolicious-white.png (base64)
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

@@ css/prettify.css (base64)
LnN0cntjb2xvcjojMDgwfS5rd2R7Y29sb3I6IzAwOH0uY29te2NvbG9yOiM4MDB9LnR5cHtjb2xv
cjojNjA2fS5saXR7Y29sb3I6IzA2Nn0ucHVue2NvbG9yOiM2NjB9LnBsbntjb2xvcjojMDAwfS50
YWd7Y29sb3I6IzAwOH0uYXRue2NvbG9yOiM2MDZ9LmF0dntjb2xvcjojMDgwfS5kZWN7Y29sb3I6
IzYwNn1wcmUucHJldHR5cHJpbnR7cGFkZGluZzoycHg7Ym9yZGVyOjFweCBzb2xpZCAjODg4fW9s
LmxpbmVudW1ze21hcmdpbi10b3A6MDttYXJnaW4tYm90dG9tOjB9bGkuTDAsbGkuTDEsbGkuTDIs
bGkuTDMsbGkuTDUsbGkuTDYsbGkuTDcsbGkuTDh7bGlzdC1zdHlsZTpub25lfWxpLkwxLGxpLkwz
LGxpLkw1LGxpLkw3LGxpLkw5e2JhY2tncm91bmQ6I2VlZX1AbWVkaWEgcHJpbnR7LnN0cntjb2xv
cjojMDYwfS5rd2R7Y29sb3I6IzAwNjtmb250LXdlaWdodDpib2xkfS5jb217Y29sb3I6IzYwMDtm
b250LXN0eWxlOml0YWxpY30udHlwe2NvbG9yOiM0MDQ7Zm9udC13ZWlnaHQ6Ym9sZH0ubGl0e2Nv
bG9yOiMwNDR9LnB1bntjb2xvcjojNDQwfS5wbG57Y29sb3I6IzAwMH0udGFne2NvbG9yOiMwMDY7
Zm9udC13ZWlnaHQ6Ym9sZH0uYXRue2NvbG9yOiM0MDR9LmF0dntjb2xvcjojMDYwfX0=

@@ css/prettify-mojo.css (base64)
LnN0ciB7IGNvbG9yOiAjOWRhYTdlOyB9Ci5rd2QgeyBjb2xvcjogI2Q1YjU3YzsgfQouY29tIHsg
Y29sb3I6ICM3MjZkNzM7IH0KLnR5cCB7IGNvbG9yOiAjZGQ3ZTVlOyB9Ci5saXQgeyBjb2xvcjog
I2ZjZjBhNDsgfQoucHVuLCAub3BuLCAuY2xvIHsgY29sb3I6ICNhNzgzNTM7IH0KLnBsbiB7IGNv
bG9yOiAjODg5ZGJjOyB9Ci50YWcgeyBjb2xvcjogI2Q1YjU3YzsgfQouYXRuIHsgY29sb3I6ICNk
ZDdlNWU7IH0KLmF0diB7IGNvbG9yOiAjOWRhYTdlOyB9Ci5kZWMgeyBjb2xvcjogI2RkN2U1ZTsg
fQ==

@@ js/jquery.js (base64)
LyohCiAqIGpRdWVyeSBKYXZhU2NyaXB0IExpYnJhcnkgdjEuNQogKiBodHRwOi8vanF1ZXJ5LmNv
bS8KICoKICogQ29weXJpZ2h0IDIwMTEsIEpvaG4gUmVzaWcKICogRHVhbCBsaWNlbnNlZCB1bmRl
ciB0aGUgTUlUIG9yIEdQTCBWZXJzaW9uIDIgbGljZW5zZXMuCiAqIGh0dHA6Ly9qcXVlcnkub3Jn
L2xpY2Vuc2UKICoKICogSW5jbHVkZXMgU2l6emxlLmpzCiAqIGh0dHA6Ly9zaXp6bGVqcy5jb20v
CiAqIENvcHlyaWdodCAyMDExLCBUaGUgRG9qbyBGb3VuZGF0aW9uCiAqIFJlbGVhc2VkIHVuZGVy
IHRoZSBNSVQsIEJTRCwgYW5kIEdQTCBMaWNlbnNlcy4KICoKICogRGF0ZTogTW9uIEphbiAzMSAw
ODozMToyOSAyMDExIC0wNTAwCiAqLwooZnVuY3Rpb24oYSxiKXtmdW5jdGlvbiBiJChhKXtyZXR1
cm4gZC5pc1dpbmRvdyhhKT9hOmEubm9kZVR5cGU9PT05P2EuZGVmYXVsdFZpZXd8fGEucGFyZW50
V2luZG93OiExfWZ1bmN0aW9uIGJYKGEpe2lmKCFiUlthXSl7dmFyIGI9ZCgiPCIrYSsiPiIpLmFw
cGVuZFRvKCJib2R5IiksYz1iLmNzcygiZGlzcGxheSIpO2IucmVtb3ZlKCk7aWYoYz09PSJub25l
Inx8Yz09PSIiKWM9ImJsb2NrIjtiUlthXT1jfXJldHVybiBiUlthXX1mdW5jdGlvbiBiVyhhLGIp
e3ZhciBjPXt9O2QuZWFjaChiVi5jb25jYXQuYXBwbHkoW10sYlYuc2xpY2UoMCxiKSksZnVuY3Rp
b24oKXtjW3RoaXNdPWF9KTtyZXR1cm4gY31mdW5jdGlvbiBiSihhLGMpe2EuZGF0YUZpbHRlciYm
KGM9YS5kYXRhRmlsdGVyKGMsYS5kYXRhVHlwZSkpO3ZhciBlPWEuZGF0YVR5cGVzLGY9YS5jb252
ZXJ0ZXJzLGcsaD1lLmxlbmd0aCxpLGo9ZVswXSxrLGwsbSxuLG87Zm9yKGc9MTtnPGg7ZysrKXtr
PWosaj1lW2ddO2lmKGo9PT0iKiIpaj1rO2Vsc2UgaWYoayE9PSIqIiYmayE9PWope2w9aysiICIr
aixtPWZbbF18fGZbIiogIitqXTtpZighbSl7bz1iO2ZvcihuIGluIGYpe2k9bi5zcGxpdCgiICIp
O2lmKGlbMF09PT1rfHxpWzBdPT09IioiKXtvPWZbaVsxXSsiICIral07aWYobyl7bj1mW25dLG49
PT0hMD9tPW86bz09PSEwJiYobT1uKTticmVha319fX0hbSYmIW8mJmQuZXJyb3IoIk5vIGNvbnZl
cnNpb24gZnJvbSAiK2wucmVwbGFjZSgiICIsIiB0byAiKSksbSE9PSEwJiYoYz1tP20oYyk6byhu
KGMpKSl9fXJldHVybiBjfWZ1bmN0aW9uIGJJKGEsYyxkKXt2YXIgZT1hLmNvbnRlbnRzLGY9YS5k
YXRhVHlwZXMsZz1hLnJlc3BvbnNlRmllbGRzLGgsaSxqLGs7Zm9yKGkgaW4gZylpIGluIGQmJihj
W2dbaV1dPWRbaV0pO3doaWxlKGZbMF09PT0iKiIpZi5zaGlmdCgpLGg9PT1iJiYoaD1jLmdldFJl
c3BvbnNlSGVhZGVyKCJjb250ZW50LXR5cGUiKSk7aWYoaClmb3IoaSBpbiBlKWlmKGVbaV0mJmVb
aV0udGVzdChoKSl7Zi51bnNoaWZ0KGkpO2JyZWFrfWlmKGZbMF1pbiBkKWo9ZlswXTtlbHNle2Zv
cihpIGluIGQpe2lmKCFmWzBdfHxhLmNvbnZlcnRlcnNbaSsiICIrZlswXV0pe2o9aTticmVha31r
fHwoaz1pKX1qPWp8fGt9aWYoail7aiE9PWZbMF0mJmYudW5zaGlmdChqKTtyZXR1cm4gZFtqXX19
ZnVuY3Rpb24gYkgoYSxiLGMsZSl7ZC5pc0FycmF5KGIpJiZiLmxlbmd0aD9kLmVhY2goYixmdW5j
dGlvbihiLGYpe2N8fGJwLnRlc3QoYSk/ZShhLGYpOmJIKGErIlsiKyh0eXBlb2YgZj09PSJvYmpl
Y3QifHxkLmlzQXJyYXkoZik/YjoiIikrIl0iLGYsYyxlKX0pOmN8fGI9PW51bGx8fHR5cGVvZiBi
IT09Im9iamVjdCI/ZShhLGIpOmQuaXNBcnJheShiKXx8ZC5pc0VtcHR5T2JqZWN0KGIpP2UoYSwi
Iik6ZC5lYWNoKGIsZnVuY3Rpb24oYixkKXtiSChhKyJbIitiKyJdIixkLGMsZSl9KX1mdW5jdGlv
biBiRyhhLGMsZCxlLGYsZyl7Zj1mfHxjLmRhdGFUeXBlc1swXSxnPWd8fHt9LGdbZl09ITA7dmFy
IGg9YVtmXSxpPTAsaj1oP2gubGVuZ3RoOjAsaz1hPT09YkQsbDtmb3IoO2k8aiYmKGt8fCFsKTtp
KyspbD1oW2ldKGMsZCxlKSx0eXBlb2YgbD09PSJzdHJpbmciJiYoZ1tsXT9sPWI6KGMuZGF0YVR5
cGVzLnVuc2hpZnQobCksbD1iRyhhLGMsZCxlLGwsZykpKTsoa3x8IWwpJiYhZ1siKiJdJiYobD1i
RyhhLGMsZCxlLCIqIixnKSk7cmV0dXJuIGx9ZnVuY3Rpb24gYkYoYSl7cmV0dXJuIGZ1bmN0aW9u
KGIsYyl7dHlwZW9mIGIhPT0ic3RyaW5nIiYmKGM9YixiPSIqIik7aWYoZC5pc0Z1bmN0aW9uKGMp
KXt2YXIgZT1iLnRvTG93ZXJDYXNlKCkuc3BsaXQoYnopLGY9MCxnPWUubGVuZ3RoLGgsaSxqO2Zv
cig7ZjxnO2YrKyloPWVbZl0saj0vXlwrLy50ZXN0KGgpLGomJihoPWguc3Vic3RyKDEpfHwiKiIp
LGk9YVtoXT1hW2hdfHxbXSxpW2o/InVuc2hpZnQiOiJwdXNoIl0oYyl9fX1mdW5jdGlvbiBibihh
LGIsYyl7dmFyIGU9Yj09PSJ3aWR0aCI/Ymg6YmksZj1iPT09IndpZHRoIj9hLm9mZnNldFdpZHRo
OmEub2Zmc2V0SGVpZ2h0O2lmKGM9PT0iYm9yZGVyIilyZXR1cm4gZjtkLmVhY2goZSxmdW5jdGlv
bigpe2N8fChmLT1wYXJzZUZsb2F0KGQuY3NzKGEsInBhZGRpbmciK3RoaXMpKXx8MCksYz09PSJt
YXJnaW4iP2YrPXBhcnNlRmxvYXQoZC5jc3MoYSwibWFyZ2luIit0aGlzKSl8fDA6Zi09cGFyc2VG
bG9hdChkLmNzcyhhLCJib3JkZXIiK3RoaXMrIldpZHRoIikpfHwwfSk7cmV0dXJuIGZ9ZnVuY3Rp
b24gXyhhLGIpe2Iuc3JjP2QuYWpheCh7dXJsOmIuc3JjLGFzeW5jOiExLGRhdGFUeXBlOiJzY3Jp
cHQifSk6ZC5nbG9iYWxFdmFsKGIudGV4dHx8Yi50ZXh0Q29udGVudHx8Yi5pbm5lckhUTUx8fCIi
KSxiLnBhcmVudE5vZGUmJmIucGFyZW50Tm9kZS5yZW1vdmVDaGlsZChiKX1mdW5jdGlvbiAkKGEs
Yil7aWYoYi5ub2RlVHlwZT09PTEpe3ZhciBjPWIubm9kZU5hbWUudG9Mb3dlckNhc2UoKTtiLmNs
ZWFyQXR0cmlidXRlcygpLGIubWVyZ2VBdHRyaWJ1dGVzKGEpO2lmKGM9PT0ib2JqZWN0IiliLm91
dGVySFRNTD1hLm91dGVySFRNTDtlbHNlIGlmKGMhPT0iaW5wdXQifHxhLnR5cGUhPT0iY2hlY2ti
b3giJiZhLnR5cGUhPT0icmFkaW8iKXtpZihjPT09Im9wdGlvbiIpYi5zZWxlY3RlZD1hLmRlZmF1
bHRTZWxlY3RlZDtlbHNlIGlmKGM9PT0iaW5wdXQifHxjPT09InRleHRhcmVhIiliLmRlZmF1bHRW
YWx1ZT1hLmRlZmF1bHRWYWx1ZX1lbHNlIGEuY2hlY2tlZCYmKGIuZGVmYXVsdENoZWNrZWQ9Yi5j
aGVja2VkPWEuY2hlY2tlZCksYi52YWx1ZSE9PWEudmFsdWUmJihiLnZhbHVlPWEudmFsdWUpO2Iu
cmVtb3ZlQXR0cmlidXRlKGQuZXhwYW5kbyl9fWZ1bmN0aW9uIFooYSxiKXtpZihiLm5vZGVUeXBl
PT09MSYmZC5oYXNEYXRhKGEpKXt2YXIgYz1kLmV4cGFuZG8sZT1kLmRhdGEoYSksZj1kLmRhdGEo
YixlKTtpZihlPWVbY10pe3ZhciBnPWUuZXZlbnRzO2Y9ZltjXT1kLmV4dGVuZCh7fSxlKTtpZihn
KXtkZWxldGUgZi5oYW5kbGUsZi5ldmVudHM9e307Zm9yKHZhciBoIGluIGcpZm9yKHZhciBpPTAs
aj1nW2hdLmxlbmd0aDtpPGo7aSsrKWQuZXZlbnQuYWRkKGIsaCxnW2hdW2ldLGdbaF1baV0uZGF0
YSl9fX19ZnVuY3Rpb24gWShhLGIpe3JldHVybiBkLm5vZGVOYW1lKGEsInRhYmxlIik/YS5nZXRF
bGVtZW50c0J5VGFnTmFtZSgidGJvZHkiKVswXXx8YS5hcHBlbmRDaGlsZChhLm93bmVyRG9jdW1l
bnQuY3JlYXRlRWxlbWVudCgidGJvZHkiKSk6YX1mdW5jdGlvbiBPKGEsYixjKXtpZihkLmlzRnVu
Y3Rpb24oYikpcmV0dXJuIGQuZ3JlcChhLGZ1bmN0aW9uKGEsZCl7dmFyIGU9ISFiLmNhbGwoYSxk
LGEpO3JldHVybiBlPT09Y30pO2lmKGIubm9kZVR5cGUpcmV0dXJuIGQuZ3JlcChhLGZ1bmN0aW9u
KGEsZCl7cmV0dXJuIGE9PT1iPT09Y30pO2lmKHR5cGVvZiBiPT09InN0cmluZyIpe3ZhciBlPWQu
Z3JlcChhLGZ1bmN0aW9uKGEpe3JldHVybiBhLm5vZGVUeXBlPT09MX0pO2lmKEoudGVzdChiKSly
ZXR1cm4gZC5maWx0ZXIoYixlLCFjKTtiPWQuZmlsdGVyKGIsZSl9cmV0dXJuIGQuZ3JlcChhLGZ1
bmN0aW9uKGEsZSl7cmV0dXJuIGQuaW5BcnJheShhLGIpPj0wPT09Y30pfWZ1bmN0aW9uIE4oYSl7
cmV0dXJuIWF8fCFhLnBhcmVudE5vZGV8fGEucGFyZW50Tm9kZS5ub2RlVHlwZT09PTExfWZ1bmN0
aW9uIEYoYSxiKXtyZXR1cm4oYSYmYSE9PSIqIj9hKyIuIjoiIikrYi5yZXBsYWNlKHEsImAiKS5y
ZXBsYWNlKHIsIiYiKX1mdW5jdGlvbiBFKGEpe3ZhciBiLGMsZSxmLGcsaCxpLGosayxsLG0sbixw
LHE9W10scj1bXSxzPWQuX2RhdGEodGhpcyx1KTt0eXBlb2Ygcz09PSJmdW5jdGlvbiImJihzPXMu
ZXZlbnRzKTtpZihhLmxpdmVGaXJlZCE9PXRoaXMmJnMmJnMubGl2ZSYmIWEudGFyZ2V0LmRpc2Fi
bGVkJiYoIWEuYnV0dG9ufHxhLnR5cGUhPT0iY2xpY2siKSl7YS5uYW1lc3BhY2UmJihuPW5ldyBS
ZWdFeHAoIihefFxcLikiK2EubmFtZXNwYWNlLnNwbGl0KCIuIikuam9pbigiXFwuKD86LipcXC4p
PyIpKyIoXFwufCQpIikpLGEubGl2ZUZpcmVkPXRoaXM7dmFyIHQ9cy5saXZlLnNsaWNlKDApO2Zv
cihpPTA7aTx0Lmxlbmd0aDtpKyspZz10W2ldLGcub3JpZ1R5cGUucmVwbGFjZShvLCIiKT09PWEu
dHlwZT9yLnB1c2goZy5zZWxlY3Rvcik6dC5zcGxpY2UoaS0tLDEpO2Y9ZChhLnRhcmdldCkuY2xv
c2VzdChyLGEuY3VycmVudFRhcmdldCk7Zm9yKGo9MCxrPWYubGVuZ3RoO2o8aztqKyspe209Zltq
XTtmb3IoaT0wO2k8dC5sZW5ndGg7aSsrKXtnPXRbaV07aWYobS5zZWxlY3Rvcj09PWcuc2VsZWN0
b3ImJighbnx8bi50ZXN0KGcubmFtZXNwYWNlKSkpe2g9bS5lbGVtLGU9bnVsbDtpZihnLnByZVR5
cGU9PT0ibW91c2VlbnRlciJ8fGcucHJlVHlwZT09PSJtb3VzZWxlYXZlIilhLnR5cGU9Zy5wcmVU
eXBlLGU9ZChhLnJlbGF0ZWRUYXJnZXQpLmNsb3Nlc3QoZy5zZWxlY3RvcilbMF07KCFlfHxlIT09
aCkmJnEucHVzaCh7ZWxlbTpoLGhhbmRsZU9iajpnLGxldmVsOm0ubGV2ZWx9KX19fWZvcihqPTAs
az1xLmxlbmd0aDtqPGs7aisrKXtmPXFbal07aWYoYyYmZi5sZXZlbD5jKWJyZWFrO2EuY3VycmVu
dFRhcmdldD1mLmVsZW0sYS5kYXRhPWYuaGFuZGxlT2JqLmRhdGEsYS5oYW5kbGVPYmo9Zi5oYW5k
bGVPYmoscD1mLmhhbmRsZU9iai5vcmlnSGFuZGxlci5hcHBseShmLmVsZW0sYXJndW1lbnRzKTtp
ZihwPT09ITF8fGEuaXNQcm9wYWdhdGlvblN0b3BwZWQoKSl7Yz1mLmxldmVsLHA9PT0hMSYmKGI9
ITEpO2lmKGEuaXNJbW1lZGlhdGVQcm9wYWdhdGlvblN0b3BwZWQoKSlicmVha319cmV0dXJuIGJ9
fWZ1bmN0aW9uIEMoYSxiLGMpe2NbMF0udHlwZT1hO3JldHVybiBkLmV2ZW50LmhhbmRsZS5hcHBs
eShiLGMpfWZ1bmN0aW9uIHcoKXtyZXR1cm4hMH1mdW5jdGlvbiB2KCl7cmV0dXJuITF9ZnVuY3Rp
b24gZihhLGMsZil7aWYoZj09PWImJmEubm9kZVR5cGU9PT0xKXtmPWEuZ2V0QXR0cmlidXRlKCJk
YXRhLSIrYyk7aWYodHlwZW9mIGY9PT0ic3RyaW5nIil7dHJ5e2Y9Zj09PSJ0cnVlIj8hMDpmPT09
ImZhbHNlIj8hMTpmPT09Im51bGwiP251bGw6ZC5pc05hTihmKT9lLnRlc3QoZik/ZC5wYXJzZUpT
T04oZik6ZjpwYXJzZUZsb2F0KGYpfWNhdGNoKGcpe31kLmRhdGEoYSxjLGYpfWVsc2UgZj1ifXJl
dHVybiBmfXZhciBjPWEuZG9jdW1lbnQsZD1mdW5jdGlvbigpe2Z1bmN0aW9uIEkoKXtpZighZC5p
c1JlYWR5KXt0cnl7Yy5kb2N1bWVudEVsZW1lbnQuZG9TY3JvbGwoImxlZnQiKX1jYXRjaChhKXtz
ZXRUaW1lb3V0KEksMSk7cmV0dXJufWQucmVhZHkoKX19dmFyIGQ9ZnVuY3Rpb24oYSxiKXtyZXR1
cm4gbmV3IGQuZm4uaW5pdChhLGIsZyl9LGU9YS5qUXVlcnksZj1hLiQsZyxoPS9eKD86W148XSoo
PFtcd1xXXSs+KVtePl0qJHwjKFtcd1wtXSspJCkvLGk9L1xTLyxqPS9eXHMrLyxrPS9ccyskLyxs
PS9cZC8sbT0vXjwoXHcrKVxzKlwvPz4oPzo8XC9cMT4pPyQvLG49L15bXF0sOnt9XHNdKiQvLG89
L1xcKD86WyJcXFwvYmZucnRdfHVbMC05YS1mQS1GXXs0fSkvZyxwPS8iW14iXFxcblxyXSoifHRy
dWV8ZmFsc2V8bnVsbHwtP1xkKyg/OlwuXGQqKT8oPzpbZUVdWytcLV0/XGQrKT8vZyxxPS8oPzpe
fDp8LCkoPzpccypcWykrL2cscj0vKHdlYmtpdClbIFwvXShbXHcuXSspLyxzPS8ob3BlcmEpKD86
Lip2ZXJzaW9uKT9bIFwvXShbXHcuXSspLyx0PS8obXNpZSkgKFtcdy5dKykvLHU9Lyhtb3ppbGxh
KSg/Oi4qPyBydjooW1x3Ll0rKSk/Lyx2PW5hdmlnYXRvci51c2VyQWdlbnQsdyx4PSExLHksej0i
dGhlbiBkb25lIGZhaWwgaXNSZXNvbHZlZCBpc1JlamVjdGVkIHByb21pc2UiLnNwbGl0KCIgIiks
QSxCPU9iamVjdC5wcm90b3R5cGUudG9TdHJpbmcsQz1PYmplY3QucHJvdG90eXBlLmhhc093blBy
b3BlcnR5LEQ9QXJyYXkucHJvdG90eXBlLnB1c2gsRT1BcnJheS5wcm90b3R5cGUuc2xpY2UsRj1T
dHJpbmcucHJvdG90eXBlLnRyaW0sRz1BcnJheS5wcm90b3R5cGUuaW5kZXhPZixIPXt9O2QuZm49
ZC5wcm90b3R5cGU9e2NvbnN0cnVjdG9yOmQsaW5pdDpmdW5jdGlvbihhLGUsZil7dmFyIGcsaSxq
LGs7aWYoIWEpcmV0dXJuIHRoaXM7aWYoYS5ub2RlVHlwZSl7dGhpcy5jb250ZXh0PXRoaXNbMF09
YSx0aGlzLmxlbmd0aD0xO3JldHVybiB0aGlzfWlmKGE9PT0iYm9keSImJiFlJiZjLmJvZHkpe3Ro
aXMuY29udGV4dD1jLHRoaXNbMF09Yy5ib2R5LHRoaXMuc2VsZWN0b3I9ImJvZHkiLHRoaXMubGVu
Z3RoPTE7cmV0dXJuIHRoaXN9aWYodHlwZW9mIGE9PT0ic3RyaW5nIil7Zz1oLmV4ZWMoYSk7aWYo
IWd8fCFnWzFdJiZlKXJldHVybiFlfHxlLmpxdWVyeT8oZXx8ZikuZmluZChhKTp0aGlzLmNvbnN0
cnVjdG9yKGUpLmZpbmQoYSk7aWYoZ1sxXSl7ZT1lIGluc3RhbmNlb2YgZD9lWzBdOmUsaz1lP2Uu
b3duZXJEb2N1bWVudHx8ZTpjLGo9bS5leGVjKGEpLGo/ZC5pc1BsYWluT2JqZWN0KGUpPyhhPVtj
LmNyZWF0ZUVsZW1lbnQoalsxXSldLGQuZm4uYXR0ci5jYWxsKGEsZSwhMCkpOmE9W2suY3JlYXRl
RWxlbWVudChqWzFdKV06KGo9ZC5idWlsZEZyYWdtZW50KFtnWzFdXSxba10pLGE9KGouY2FjaGVh
YmxlP2QuY2xvbmUoai5mcmFnbWVudCk6ai5mcmFnbWVudCkuY2hpbGROb2Rlcyk7cmV0dXJuIGQu
bWVyZ2UodGhpcyxhKX1pPWMuZ2V0RWxlbWVudEJ5SWQoZ1syXSk7aWYoaSYmaS5wYXJlbnROb2Rl
KXtpZihpLmlkIT09Z1syXSlyZXR1cm4gZi5maW5kKGEpO3RoaXMubGVuZ3RoPTEsdGhpc1swXT1p
fXRoaXMuY29udGV4dD1jLHRoaXMuc2VsZWN0b3I9YTtyZXR1cm4gdGhpc31pZihkLmlzRnVuY3Rp
b24oYSkpcmV0dXJuIGYucmVhZHkoYSk7YS5zZWxlY3RvciE9PWImJih0aGlzLnNlbGVjdG9yPWEu
c2VsZWN0b3IsdGhpcy5jb250ZXh0PWEuY29udGV4dCk7cmV0dXJuIGQubWFrZUFycmF5KGEsdGhp
cyl9LHNlbGVjdG9yOiIiLGpxdWVyeToiMS41IixsZW5ndGg6MCxzaXplOmZ1bmN0aW9uKCl7cmV0
dXJuIHRoaXMubGVuZ3RofSx0b0FycmF5OmZ1bmN0aW9uKCl7cmV0dXJuIEUuY2FsbCh0aGlzLDAp
fSxnZXQ6ZnVuY3Rpb24oYSl7cmV0dXJuIGE9PW51bGw/dGhpcy50b0FycmF5KCk6YTwwP3RoaXNb
dGhpcy5sZW5ndGgrYV06dGhpc1thXX0scHVzaFN0YWNrOmZ1bmN0aW9uKGEsYixjKXt2YXIgZT10
aGlzLmNvbnN0cnVjdG9yKCk7ZC5pc0FycmF5KGEpP0QuYXBwbHkoZSxhKTpkLm1lcmdlKGUsYSks
ZS5wcmV2T2JqZWN0PXRoaXMsZS5jb250ZXh0PXRoaXMuY29udGV4dCxiPT09ImZpbmQiP2Uuc2Vs
ZWN0b3I9dGhpcy5zZWxlY3RvcisodGhpcy5zZWxlY3Rvcj8iICI6IiIpK2M6YiYmKGUuc2VsZWN0
b3I9dGhpcy5zZWxlY3RvcisiLiIrYisiKCIrYysiKSIpO3JldHVybiBlfSxlYWNoOmZ1bmN0aW9u
KGEsYil7cmV0dXJuIGQuZWFjaCh0aGlzLGEsYil9LHJlYWR5OmZ1bmN0aW9uKGEpe2QuYmluZFJl
YWR5KCkseS5kb25lKGEpO3JldHVybiB0aGlzfSxlcTpmdW5jdGlvbihhKXtyZXR1cm4gYT09PS0x
P3RoaXMuc2xpY2UoYSk6dGhpcy5zbGljZShhLCthKzEpfSxmaXJzdDpmdW5jdGlvbigpe3JldHVy
biB0aGlzLmVxKDApfSxsYXN0OmZ1bmN0aW9uKCl7cmV0dXJuIHRoaXMuZXEoLTEpfSxzbGljZTpm
dW5jdGlvbigpe3JldHVybiB0aGlzLnB1c2hTdGFjayhFLmFwcGx5KHRoaXMsYXJndW1lbnRzKSwi
c2xpY2UiLEUuY2FsbChhcmd1bWVudHMpLmpvaW4oIiwiKSl9LG1hcDpmdW5jdGlvbihhKXtyZXR1
cm4gdGhpcy5wdXNoU3RhY2soZC5tYXAodGhpcyxmdW5jdGlvbihiLGMpe3JldHVybiBhLmNhbGwo
YixjLGIpfSkpfSxlbmQ6ZnVuY3Rpb24oKXtyZXR1cm4gdGhpcy5wcmV2T2JqZWN0fHx0aGlzLmNv
bnN0cnVjdG9yKG51bGwpfSxwdXNoOkQsc29ydDpbXS5zb3J0LHNwbGljZTpbXS5zcGxpY2V9LGQu
Zm4uaW5pdC5wcm90b3R5cGU9ZC5mbixkLmV4dGVuZD1kLmZuLmV4dGVuZD1mdW5jdGlvbigpe3Zh
ciBhLGMsZSxmLGcsaCxpPWFyZ3VtZW50c1swXXx8e30saj0xLGs9YXJndW1lbnRzLmxlbmd0aCxs
PSExO3R5cGVvZiBpPT09ImJvb2xlYW4iJiYobD1pLGk9YXJndW1lbnRzWzFdfHx7fSxqPTIpLHR5
cGVvZiBpIT09Im9iamVjdCImJiFkLmlzRnVuY3Rpb24oaSkmJihpPXt9KSxrPT09aiYmKGk9dGhp
cywtLWopO2Zvcig7ajxrO2orKylpZigoYT1hcmd1bWVudHNbal0pIT1udWxsKWZvcihjIGluIGEp
e2U9aVtjXSxmPWFbY107aWYoaT09PWYpY29udGludWU7bCYmZiYmKGQuaXNQbGFpbk9iamVjdChm
KXx8KGc9ZC5pc0FycmF5KGYpKSk/KGc/KGc9ITEsaD1lJiZkLmlzQXJyYXkoZSk/ZTpbXSk6aD1l
JiZkLmlzUGxhaW5PYmplY3QoZSk/ZTp7fSxpW2NdPWQuZXh0ZW5kKGwsaCxmKSk6ZiE9PWImJihp
W2NdPWYpfXJldHVybiBpfSxkLmV4dGVuZCh7bm9Db25mbGljdDpmdW5jdGlvbihiKXthLiQ9Zixi
JiYoYS5qUXVlcnk9ZSk7cmV0dXJuIGR9LGlzUmVhZHk6ITEscmVhZHlXYWl0OjEscmVhZHk6ZnVu
Y3Rpb24oYSl7YT09PSEwJiZkLnJlYWR5V2FpdC0tO2lmKCFkLnJlYWR5V2FpdHx8YSE9PSEwJiYh
ZC5pc1JlYWR5KXtpZighYy5ib2R5KXJldHVybiBzZXRUaW1lb3V0KGQucmVhZHksMSk7ZC5pc1Jl
YWR5PSEwO2lmKGEhPT0hMCYmLS1kLnJlYWR5V2FpdD4wKXJldHVybjt5LnJlc29sdmVXaXRoKGMs
W2RdKSxkLmZuLnRyaWdnZXImJmQoYykudHJpZ2dlcigicmVhZHkiKS51bmJpbmQoInJlYWR5Iil9
fSxiaW5kUmVhZHk6ZnVuY3Rpb24oKXtpZigheCl7eD0hMDtpZihjLnJlYWR5U3RhdGU9PT0iY29t
cGxldGUiKXJldHVybiBzZXRUaW1lb3V0KGQucmVhZHksMSk7aWYoYy5hZGRFdmVudExpc3RlbmVy
KWMuYWRkRXZlbnRMaXN0ZW5lcigiRE9NQ29udGVudExvYWRlZCIsQSwhMSksYS5hZGRFdmVudExp
c3RlbmVyKCJsb2FkIixkLnJlYWR5LCExKTtlbHNlIGlmKGMuYXR0YWNoRXZlbnQpe2MuYXR0YWNo
RXZlbnQoIm9ucmVhZHlzdGF0ZWNoYW5nZSIsQSksYS5hdHRhY2hFdmVudCgib25sb2FkIixkLnJl
YWR5KTt2YXIgYj0hMTt0cnl7Yj1hLmZyYW1lRWxlbWVudD09bnVsbH1jYXRjaChlKXt9Yy5kb2N1
bWVudEVsZW1lbnQuZG9TY3JvbGwmJmImJkkoKX19fSxpc0Z1bmN0aW9uOmZ1bmN0aW9uKGEpe3Jl
dHVybiBkLnR5cGUoYSk9PT0iZnVuY3Rpb24ifSxpc0FycmF5OkFycmF5LmlzQXJyYXl8fGZ1bmN0
aW9uKGEpe3JldHVybiBkLnR5cGUoYSk9PT0iYXJyYXkifSxpc1dpbmRvdzpmdW5jdGlvbihhKXty
ZXR1cm4gYSYmdHlwZW9mIGE9PT0ib2JqZWN0IiYmInNldEludGVydmFsImluIGF9LGlzTmFOOmZ1
bmN0aW9uKGEpe3JldHVybiBhPT1udWxsfHwhbC50ZXN0KGEpfHxpc05hTihhKX0sdHlwZTpmdW5j
dGlvbihhKXtyZXR1cm4gYT09bnVsbD9TdHJpbmcoYSk6SFtCLmNhbGwoYSldfHwib2JqZWN0In0s
aXNQbGFpbk9iamVjdDpmdW5jdGlvbihhKXtpZighYXx8ZC50eXBlKGEpIT09Im9iamVjdCJ8fGEu
bm9kZVR5cGV8fGQuaXNXaW5kb3coYSkpcmV0dXJuITE7aWYoYS5jb25zdHJ1Y3RvciYmIUMuY2Fs
bChhLCJjb25zdHJ1Y3RvciIpJiYhQy5jYWxsKGEuY29uc3RydWN0b3IucHJvdG90eXBlLCJpc1By
b3RvdHlwZU9mIikpcmV0dXJuITE7dmFyIGM7Zm9yKGMgaW4gYSl7fXJldHVybiBjPT09Ynx8Qy5j
YWxsKGEsYyl9LGlzRW1wdHlPYmplY3Q6ZnVuY3Rpb24oYSl7Zm9yKHZhciBiIGluIGEpcmV0dXJu
ITE7cmV0dXJuITB9LGVycm9yOmZ1bmN0aW9uKGEpe3Rocm93IGF9LHBhcnNlSlNPTjpmdW5jdGlv
bihiKXtpZih0eXBlb2YgYiE9PSJzdHJpbmcifHwhYilyZXR1cm4gbnVsbDtiPWQudHJpbShiKTtp
ZihuLnRlc3QoYi5yZXBsYWNlKG8sIkAiKS5yZXBsYWNlKHAsIl0iKS5yZXBsYWNlKHEsIiIpKSly
ZXR1cm4gYS5KU09OJiZhLkpTT04ucGFyc2U/YS5KU09OLnBhcnNlKGIpOihuZXcgRnVuY3Rpb24o
InJldHVybiAiK2IpKSgpO2QuZXJyb3IoIkludmFsaWQgSlNPTjogIitiKX0scGFyc2VYTUw6ZnVu
Y3Rpb24oYixjLGUpe2EuRE9NUGFyc2VyPyhlPW5ldyBET01QYXJzZXIsYz1lLnBhcnNlRnJvbVN0
cmluZyhiLCJ0ZXh0L3htbCIpKTooYz1uZXcgQWN0aXZlWE9iamVjdCgiTWljcm9zb2Z0LlhNTERP
TSIpLGMuYXN5bmM9ImZhbHNlIixjLmxvYWRYTUwoYikpLGU9Yy5kb2N1bWVudEVsZW1lbnQsKCFl
fHwhZS5ub2RlTmFtZXx8ZS5ub2RlTmFtZT09PSJwYXJzZXJlcnJvciIpJiZkLmVycm9yKCJJbnZh
bGlkIFhNTDogIitiKTtyZXR1cm4gY30sbm9vcDpmdW5jdGlvbigpe30sZ2xvYmFsRXZhbDpmdW5j
dGlvbihhKXtpZihhJiZpLnRlc3QoYSkpe3ZhciBiPWMuZ2V0RWxlbWVudHNCeVRhZ05hbWUoImhl
YWQiKVswXXx8Yy5kb2N1bWVudEVsZW1lbnQsZT1jLmNyZWF0ZUVsZW1lbnQoInNjcmlwdCIpO2Uu
dHlwZT0idGV4dC9qYXZhc2NyaXB0IixkLnN1cHBvcnQuc2NyaXB0RXZhbCgpP2UuYXBwZW5kQ2hp
bGQoYy5jcmVhdGVUZXh0Tm9kZShhKSk6ZS50ZXh0PWEsYi5pbnNlcnRCZWZvcmUoZSxiLmZpcnN0
Q2hpbGQpLGIucmVtb3ZlQ2hpbGQoZSl9fSxub2RlTmFtZTpmdW5jdGlvbihhLGIpe3JldHVybiBh
Lm5vZGVOYW1lJiZhLm5vZGVOYW1lLnRvVXBwZXJDYXNlKCk9PT1iLnRvVXBwZXJDYXNlKCl9LGVh
Y2g6ZnVuY3Rpb24oYSxjLGUpe3ZhciBmLGc9MCxoPWEubGVuZ3RoLGk9aD09PWJ8fGQuaXNGdW5j
dGlvbihhKTtpZihlKXtpZihpKXtmb3IoZiBpbiBhKWlmKGMuYXBwbHkoYVtmXSxlKT09PSExKWJy
ZWFrfWVsc2UgZm9yKDtnPGg7KWlmKGMuYXBwbHkoYVtnKytdLGUpPT09ITEpYnJlYWt9ZWxzZSBp
ZihpKXtmb3IoZiBpbiBhKWlmKGMuY2FsbChhW2ZdLGYsYVtmXSk9PT0hMSlicmVha31lbHNlIGZv
cih2YXIgaj1hWzBdO2c8aCYmYy5jYWxsKGosZyxqKSE9PSExO2o9YVsrK2ddKXt9cmV0dXJuIGF9
LHRyaW06Rj9mdW5jdGlvbihhKXtyZXR1cm4gYT09bnVsbD8iIjpGLmNhbGwoYSl9OmZ1bmN0aW9u
KGEpe3JldHVybiBhPT1udWxsPyIiOihhKyIiKS5yZXBsYWNlKGosIiIpLnJlcGxhY2UoaywiIil9
LG1ha2VBcnJheTpmdW5jdGlvbihhLGIpe3ZhciBjPWJ8fFtdO2lmKGEhPW51bGwpe3ZhciBlPWQu
dHlwZShhKTthLmxlbmd0aD09bnVsbHx8ZT09PSJzdHJpbmcifHxlPT09ImZ1bmN0aW9uInx8ZT09
PSJyZWdleHAifHxkLmlzV2luZG93KGEpP0QuY2FsbChjLGEpOmQubWVyZ2UoYyxhKX1yZXR1cm4g
Y30saW5BcnJheTpmdW5jdGlvbihhLGIpe2lmKGIuaW5kZXhPZilyZXR1cm4gYi5pbmRleE9mKGEp
O2Zvcih2YXIgYz0wLGQ9Yi5sZW5ndGg7YzxkO2MrKylpZihiW2NdPT09YSlyZXR1cm4gYztyZXR1
cm4tMX0sbWVyZ2U6ZnVuY3Rpb24oYSxjKXt2YXIgZD1hLmxlbmd0aCxlPTA7aWYodHlwZW9mIGMu
bGVuZ3RoPT09Im51bWJlciIpZm9yKHZhciBmPWMubGVuZ3RoO2U8ZjtlKyspYVtkKytdPWNbZV07
ZWxzZSB3aGlsZShjW2VdIT09YilhW2QrK109Y1tlKytdO2EubGVuZ3RoPWQ7cmV0dXJuIGF9LGdy
ZXA6ZnVuY3Rpb24oYSxiLGMpe3ZhciBkPVtdLGU7Yz0hIWM7Zm9yKHZhciBmPTAsZz1hLmxlbmd0
aDtmPGc7ZisrKWU9ISFiKGFbZl0sZiksYyE9PWUmJmQucHVzaChhW2ZdKTtyZXR1cm4gZH0sbWFw
OmZ1bmN0aW9uKGEsYixjKXt2YXIgZD1bXSxlO2Zvcih2YXIgZj0wLGc9YS5sZW5ndGg7ZjxnO2Yr
KyllPWIoYVtmXSxmLGMpLGUhPW51bGwmJihkW2QubGVuZ3RoXT1lKTtyZXR1cm4gZC5jb25jYXQu
YXBwbHkoW10sZCl9LGd1aWQ6MSxwcm94eTpmdW5jdGlvbihhLGMsZSl7YXJndW1lbnRzLmxlbmd0
aD09PTImJih0eXBlb2YgYz09PSJzdHJpbmciPyhlPWEsYT1lW2NdLGM9Yik6YyYmIWQuaXNGdW5j
dGlvbihjKSYmKGU9YyxjPWIpKSwhYyYmYSYmKGM9ZnVuY3Rpb24oKXtyZXR1cm4gYS5hcHBseShl
fHx0aGlzLGFyZ3VtZW50cyl9KSxhJiYoYy5ndWlkPWEuZ3VpZD1hLmd1aWR8fGMuZ3VpZHx8ZC5n
dWlkKyspO3JldHVybiBjfSxhY2Nlc3M6ZnVuY3Rpb24oYSxjLGUsZixnLGgpe3ZhciBpPWEubGVu
Z3RoO2lmKHR5cGVvZiBjPT09Im9iamVjdCIpe2Zvcih2YXIgaiBpbiBjKWQuYWNjZXNzKGEsaixj
W2pdLGYsZyxlKTtyZXR1cm4gYX1pZihlIT09Yil7Zj0haCYmZiYmZC5pc0Z1bmN0aW9uKGUpO2Zv
cih2YXIgaz0wO2s8aTtrKyspZyhhW2tdLGMsZj9lLmNhbGwoYVtrXSxrLGcoYVtrXSxjKSk6ZSxo
KTtyZXR1cm4gYX1yZXR1cm4gaT9nKGFbMF0sYyk6Yn0sbm93OmZ1bmN0aW9uKCl7cmV0dXJuKG5l
dyBEYXRlKS5nZXRUaW1lKCl9LF9EZWZlcnJlZDpmdW5jdGlvbigpe3ZhciBhPVtdLGIsYyxlLGY9
e2RvbmU6ZnVuY3Rpb24oKXtpZighZSl7dmFyIGM9YXJndW1lbnRzLGcsaCxpLGosaztiJiYoaz1i
LGI9MCk7Zm9yKGc9MCxoPWMubGVuZ3RoO2c8aDtnKyspaT1jW2ddLGo9ZC50eXBlKGkpLGo9PT0i
YXJyYXkiP2YuZG9uZS5hcHBseShmLGkpOmo9PT0iZnVuY3Rpb24iJiZhLnB1c2goaSk7ayYmZi5y
ZXNvbHZlV2l0aChrWzBdLGtbMV0pfXJldHVybiB0aGlzfSxyZXNvbHZlV2l0aDpmdW5jdGlvbihk
LGYpe2lmKCFlJiYhYiYmIWMpe2M9MTt0cnl7d2hpbGUoYVswXSlhLnNoaWZ0KCkuYXBwbHkoZCxm
KX1maW5hbGx5e2I9W2QsZl0sYz0wfX1yZXR1cm4gdGhpc30scmVzb2x2ZTpmdW5jdGlvbigpe2Yu
cmVzb2x2ZVdpdGgoZC5pc0Z1bmN0aW9uKHRoaXMucHJvbWlzZSk/dGhpcy5wcm9taXNlKCk6dGhp
cyxhcmd1bWVudHMpO3JldHVybiB0aGlzfSxpc1Jlc29sdmVkOmZ1bmN0aW9uKCl7cmV0dXJuIGN8
fGJ9LGNhbmNlbDpmdW5jdGlvbigpe2U9MSxhPVtdO3JldHVybiB0aGlzfX07cmV0dXJuIGZ9LERl
ZmVycmVkOmZ1bmN0aW9uKGEpe3ZhciBiPWQuX0RlZmVycmVkKCksYz1kLl9EZWZlcnJlZCgpLGU7
ZC5leHRlbmQoYix7dGhlbjpmdW5jdGlvbihhLGMpe2IuZG9uZShhKS5mYWlsKGMpO3JldHVybiB0
aGlzfSxmYWlsOmMuZG9uZSxyZWplY3RXaXRoOmMucmVzb2x2ZVdpdGgscmVqZWN0OmMucmVzb2x2
ZSxpc1JlamVjdGVkOmMuaXNSZXNvbHZlZCxwcm9taXNlOmZ1bmN0aW9uKGEsYyl7aWYoYT09bnVs
bCl7aWYoZSlyZXR1cm4gZTtlPWE9e319Yz16Lmxlbmd0aDt3aGlsZShjLS0pYVt6W2NdXT1iW3pb
Y11dO3JldHVybiBhfX0pLGIudGhlbihjLmNhbmNlbCxiLmNhbmNlbCksZGVsZXRlIGIuY2FuY2Vs
LGEmJmEuY2FsbChiLGIpO3JldHVybiBifSx3aGVuOmZ1bmN0aW9uKGEpe3ZhciBiPWFyZ3VtZW50
cyxjPWIubGVuZ3RoLGU9Yzw9MSYmYSYmZC5pc0Z1bmN0aW9uKGEucHJvbWlzZSk/YTpkLkRlZmVy
cmVkKCksZj1lLnByb21pc2UoKSxnO2M+MT8oZz1BcnJheShjKSxkLmVhY2goYixmdW5jdGlvbihh
LGIpe2Qud2hlbihiKS50aGVuKGZ1bmN0aW9uKGIpe2dbYV09YXJndW1lbnRzLmxlbmd0aD4xP0Uu
Y2FsbChhcmd1bWVudHMsMCk6YiwtLWN8fGUucmVzb2x2ZVdpdGgoZixnKX0sZS5yZWplY3QpfSkp
OmUhPT1hJiZlLnJlc29sdmUoYSk7cmV0dXJuIGZ9LHVhTWF0Y2g6ZnVuY3Rpb24oYSl7YT1hLnRv
TG93ZXJDYXNlKCk7dmFyIGI9ci5leGVjKGEpfHxzLmV4ZWMoYSl8fHQuZXhlYyhhKXx8YS5pbmRl
eE9mKCJjb21wYXRpYmxlIik8MCYmdS5leGVjKGEpfHxbXTtyZXR1cm57YnJvd3NlcjpiWzFdfHwi
Iix2ZXJzaW9uOmJbMl18fCIwIn19LHN1YjpmdW5jdGlvbigpe2Z1bmN0aW9uIGEoYixjKXtyZXR1
cm4gbmV3IGEuZm4uaW5pdChiLGMpfWQuZXh0ZW5kKCEwLGEsdGhpcyksYS5zdXBlcmNsYXNzPXRo
aXMsYS5mbj1hLnByb3RvdHlwZT10aGlzKCksYS5mbi5jb25zdHJ1Y3Rvcj1hLGEuc3ViY2xhc3M9
dGhpcy5zdWJjbGFzcyxhLmZuLmluaXQ9ZnVuY3Rpb24gYihiLGMpe2MmJmMgaW5zdGFuY2VvZiBk
JiYhKGMgaW5zdGFuY2VvZiBhKSYmKGM9YShjKSk7cmV0dXJuIGQuZm4uaW5pdC5jYWxsKHRoaXMs
YixjLGUpfSxhLmZuLmluaXQucHJvdG90eXBlPWEuZm47dmFyIGU9YShjKTtyZXR1cm4gYX0sYnJv
d3Nlcjp7fX0pLHk9ZC5fRGVmZXJyZWQoKSxkLmVhY2goIkJvb2xlYW4gTnVtYmVyIFN0cmluZyBG
dW5jdGlvbiBBcnJheSBEYXRlIFJlZ0V4cCBPYmplY3QiLnNwbGl0KCIgIiksZnVuY3Rpb24oYSxi
KXtIWyJbb2JqZWN0ICIrYisiXSJdPWIudG9Mb3dlckNhc2UoKX0pLHc9ZC51YU1hdGNoKHYpLHcu
YnJvd3NlciYmKGQuYnJvd3Nlclt3LmJyb3dzZXJdPSEwLGQuYnJvd3Nlci52ZXJzaW9uPXcudmVy
c2lvbiksZC5icm93c2VyLndlYmtpdCYmKGQuYnJvd3Nlci5zYWZhcmk9ITApLEcmJihkLmluQXJy
YXk9ZnVuY3Rpb24oYSxiKXtyZXR1cm4gRy5jYWxsKGIsYSl9KSxpLnRlc3QoIsKgIikmJihqPS9e
W1xzXHhBMF0rLyxrPS9bXHNceEEwXSskLyksZz1kKGMpLGMuYWRkRXZlbnRMaXN0ZW5lcj9BPWZ1
bmN0aW9uKCl7Yy5yZW1vdmVFdmVudExpc3RlbmVyKCJET01Db250ZW50TG9hZGVkIixBLCExKSxk
LnJlYWR5KCl9OmMuYXR0YWNoRXZlbnQmJihBPWZ1bmN0aW9uKCl7Yy5yZWFkeVN0YXRlPT09ImNv
bXBsZXRlIiYmKGMuZGV0YWNoRXZlbnQoIm9ucmVhZHlzdGF0ZWNoYW5nZSIsQSksZC5yZWFkeSgp
KX0pO3JldHVybiBhLmpRdWVyeT1hLiQ9ZH0oKTsoZnVuY3Rpb24oKXtkLnN1cHBvcnQ9e307dmFy
IGI9Yy5jcmVhdGVFbGVtZW50KCJkaXYiKTtiLnN0eWxlLmRpc3BsYXk9Im5vbmUiLGIuaW5uZXJI
VE1MPSIgICA8bGluay8+PHRhYmxlPjwvdGFibGU+PGEgaHJlZj0nL2EnIHN0eWxlPSdjb2xvcjpy
ZWQ7ZmxvYXQ6bGVmdDtvcGFjaXR5Oi41NTsnPmE8L2E+PGlucHV0IHR5cGU9J2NoZWNrYm94Jy8+
Ijt2YXIgZT1iLmdldEVsZW1lbnRzQnlUYWdOYW1lKCIqIiksZj1iLmdldEVsZW1lbnRzQnlUYWdO
YW1lKCJhIilbMF0sZz1jLmNyZWF0ZUVsZW1lbnQoInNlbGVjdCIpLGg9Zy5hcHBlbmRDaGlsZChj
LmNyZWF0ZUVsZW1lbnQoIm9wdGlvbiIpKTtpZihlJiZlLmxlbmd0aCYmZil7ZC5zdXBwb3J0PXts
ZWFkaW5nV2hpdGVzcGFjZTpiLmZpcnN0Q2hpbGQubm9kZVR5cGU9PT0zLHRib2R5OiFiLmdldEVs
ZW1lbnRzQnlUYWdOYW1lKCJ0Ym9keSIpLmxlbmd0aCxodG1sU2VyaWFsaXplOiEhYi5nZXRFbGVt
ZW50c0J5VGFnTmFtZSgibGluayIpLmxlbmd0aCxzdHlsZTovcmVkLy50ZXN0KGYuZ2V0QXR0cmli
dXRlKCJzdHlsZSIpKSxocmVmTm9ybWFsaXplZDpmLmdldEF0dHJpYnV0ZSgiaHJlZiIpPT09Ii9h
IixvcGFjaXR5Oi9eMC41NSQvLnRlc3QoZi5zdHlsZS5vcGFjaXR5KSxjc3NGbG9hdDohIWYuc3R5
bGUuY3NzRmxvYXQsY2hlY2tPbjpiLmdldEVsZW1lbnRzQnlUYWdOYW1lKCJpbnB1dCIpWzBdLnZh
bHVlPT09Im9uIixvcHRTZWxlY3RlZDpoLnNlbGVjdGVkLGRlbGV0ZUV4cGFuZG86ITAsb3B0RGlz
YWJsZWQ6ITEsY2hlY2tDbG9uZTohMSxfc2NyaXB0RXZhbDpudWxsLG5vQ2xvbmVFdmVudDohMCxi
b3hNb2RlbDpudWxsLGlubGluZUJsb2NrTmVlZHNMYXlvdXQ6ITEsc2hyaW5rV3JhcEJsb2Nrczoh
MSxyZWxpYWJsZUhpZGRlbk9mZnNldHM6ITB9LGcuZGlzYWJsZWQ9ITAsZC5zdXBwb3J0Lm9wdERp
c2FibGVkPSFoLmRpc2FibGVkLGQuc3VwcG9ydC5zY3JpcHRFdmFsPWZ1bmN0aW9uKCl7aWYoZC5z
dXBwb3J0Ll9zY3JpcHRFdmFsPT09bnVsbCl7dmFyIGI9Yy5kb2N1bWVudEVsZW1lbnQsZT1jLmNy
ZWF0ZUVsZW1lbnQoInNjcmlwdCIpLGY9InNjcmlwdCIrZC5ub3coKTtlLnR5cGU9InRleHQvamF2
YXNjcmlwdCI7dHJ5e2UuYXBwZW5kQ2hpbGQoYy5jcmVhdGVUZXh0Tm9kZSgid2luZG93LiIrZisi
PTE7IikpfWNhdGNoKGcpe31iLmluc2VydEJlZm9yZShlLGIuZmlyc3RDaGlsZCksYVtmXT8oZC5z
dXBwb3J0Ll9zY3JpcHRFdmFsPSEwLGRlbGV0ZSBhW2ZdKTpkLnN1cHBvcnQuX3NjcmlwdEV2YWw9
ITEsYi5yZW1vdmVDaGlsZChlKSxiPWU9Zj1udWxsfXJldHVybiBkLnN1cHBvcnQuX3NjcmlwdEV2
YWx9O3RyeXtkZWxldGUgYi50ZXN0fWNhdGNoKGkpe2Quc3VwcG9ydC5kZWxldGVFeHBhbmRvPSEx
fWIuYXR0YWNoRXZlbnQmJmIuZmlyZUV2ZW50JiYoYi5hdHRhY2hFdmVudCgib25jbGljayIsZnVu
Y3Rpb24gaigpe2Quc3VwcG9ydC5ub0Nsb25lRXZlbnQ9ITEsYi5kZXRhY2hFdmVudCgib25jbGlj
ayIsail9KSxiLmNsb25lTm9kZSghMCkuZmlyZUV2ZW50KCJvbmNsaWNrIikpLGI9Yy5jcmVhdGVF
bGVtZW50KCJkaXYiKSxiLmlubmVySFRNTD0iPGlucHV0IHR5cGU9J3JhZGlvJyBuYW1lPSdyYWRp
b3Rlc3QnIGNoZWNrZWQ9J2NoZWNrZWQnLz4iO3ZhciBrPWMuY3JlYXRlRG9jdW1lbnRGcmFnbWVu
dCgpO2suYXBwZW5kQ2hpbGQoYi5maXJzdENoaWxkKSxkLnN1cHBvcnQuY2hlY2tDbG9uZT1rLmNs
b25lTm9kZSghMCkuY2xvbmVOb2RlKCEwKS5sYXN0Q2hpbGQuY2hlY2tlZCxkKGZ1bmN0aW9uKCl7
dmFyIGE9Yy5jcmVhdGVFbGVtZW50KCJkaXYiKSxiPWMuZ2V0RWxlbWVudHNCeVRhZ05hbWUoImJv
ZHkiKVswXTtpZihiKXthLnN0eWxlLndpZHRoPWEuc3R5bGUucGFkZGluZ0xlZnQ9IjFweCIsYi5h
cHBlbmRDaGlsZChhKSxkLmJveE1vZGVsPWQuc3VwcG9ydC5ib3hNb2RlbD1hLm9mZnNldFdpZHRo
PT09Miwiem9vbSJpbiBhLnN0eWxlJiYoYS5zdHlsZS5kaXNwbGF5PSJpbmxpbmUiLGEuc3R5bGUu
em9vbT0xLGQuc3VwcG9ydC5pbmxpbmVCbG9ja05lZWRzTGF5b3V0PWEub2Zmc2V0V2lkdGg9PT0y
LGEuc3R5bGUuZGlzcGxheT0iIixhLmlubmVySFRNTD0iPGRpdiBzdHlsZT0nd2lkdGg6NHB4Oyc+
PC9kaXY+IixkLnN1cHBvcnQuc2hyaW5rV3JhcEJsb2Nrcz1hLm9mZnNldFdpZHRoIT09MiksYS5p
bm5lckhUTUw9Ijx0YWJsZT48dHI+PHRkIHN0eWxlPSdwYWRkaW5nOjA7Ym9yZGVyOjA7ZGlzcGxh
eTpub25lJz48L3RkPjx0ZD50PC90ZD48L3RyPjwvdGFibGU+Ijt2YXIgZT1hLmdldEVsZW1lbnRz
QnlUYWdOYW1lKCJ0ZCIpO2Quc3VwcG9ydC5yZWxpYWJsZUhpZGRlbk9mZnNldHM9ZVswXS5vZmZz
ZXRIZWlnaHQ9PT0wLGVbMF0uc3R5bGUuZGlzcGxheT0iIixlWzFdLnN0eWxlLmRpc3BsYXk9Im5v
bmUiLGQuc3VwcG9ydC5yZWxpYWJsZUhpZGRlbk9mZnNldHM9ZC5zdXBwb3J0LnJlbGlhYmxlSGlk
ZGVuT2Zmc2V0cyYmZVswXS5vZmZzZXRIZWlnaHQ9PT0wLGEuaW5uZXJIVE1MPSIiLGIucmVtb3Zl
Q2hpbGQoYSkuc3R5bGUuZGlzcGxheT0ibm9uZSIsYT1lPW51bGx9fSk7dmFyIGw9ZnVuY3Rpb24o
YSl7dmFyIGI9Yy5jcmVhdGVFbGVtZW50KCJkaXYiKTthPSJvbiIrYTtpZighYi5hdHRhY2hFdmVu
dClyZXR1cm4hMDt2YXIgZD1hIGluIGI7ZHx8KGIuc2V0QXR0cmlidXRlKGEsInJldHVybjsiKSxk
PXR5cGVvZiBiW2FdPT09ImZ1bmN0aW9uIiksYj1udWxsO3JldHVybiBkfTtkLnN1cHBvcnQuc3Vi
bWl0QnViYmxlcz1sKCJzdWJtaXQiKSxkLnN1cHBvcnQuY2hhbmdlQnViYmxlcz1sKCJjaGFuZ2Ui
KSxiPWU9Zj1udWxsfX0pKCk7dmFyIGU9L14oPzpcey4qXH18XFsuKlxdKSQvO2QuZXh0ZW5kKHtj
YWNoZTp7fSx1dWlkOjAsZXhwYW5kbzoialF1ZXJ5IisoZC5mbi5qcXVlcnkrTWF0aC5yYW5kb20o
KSkucmVwbGFjZSgvXEQvZywiIiksbm9EYXRhOntlbWJlZDohMCxvYmplY3Q6ImNsc2lkOkQyN0NE
QjZFLUFFNkQtMTFjZi05NkI4LTQ0NDU1MzU0MDAwMCIsYXBwbGV0OiEwfSxoYXNEYXRhOmZ1bmN0
aW9uKGEpe2E9YS5ub2RlVHlwZT9kLmNhY2hlW2FbZC5leHBhbmRvXV06YVtkLmV4cGFuZG9dO3Jl
dHVybiEhYSYmIWQuaXNFbXB0eU9iamVjdChhKX0sZGF0YTpmdW5jdGlvbihhLGMsZSxmKXtpZihk
LmFjY2VwdERhdGEoYSkpe3ZhciBnPWQuZXhwYW5kbyxoPXR5cGVvZiBjPT09InN0cmluZyIsaSxq
PWEubm9kZVR5cGUsaz1qP2QuY2FjaGU6YSxsPWo/YVtkLmV4cGFuZG9dOmFbZC5leHBhbmRvXSYm
ZC5leHBhbmRvO2lmKCghbHx8ZiYmbCYmIWtbbF1bZ10pJiZoJiZlPT09YilyZXR1cm47bHx8KGo/
YVtkLmV4cGFuZG9dPWw9KytkLnV1aWQ6bD1kLmV4cGFuZG8pLGtbbF18fChrW2xdPXt9KSx0eXBl
b2YgYz09PSJvYmplY3QiJiYoZj9rW2xdW2ddPWQuZXh0ZW5kKGtbbF1bZ10sYyk6a1tsXT1kLmV4
dGVuZChrW2xdLGMpKSxpPWtbbF0sZiYmKGlbZ118fChpW2ddPXt9KSxpPWlbZ10pLGUhPT1iJiYo
aVtjXT1lKTtpZihjPT09ImV2ZW50cyImJiFpW2NdKXJldHVybiBpW2ddJiZpW2ddLmV2ZW50czty
ZXR1cm4gaD9pW2NdOml9fSxyZW1vdmVEYXRhOmZ1bmN0aW9uKGIsYyxlKXtpZihkLmFjY2VwdERh
dGEoYikpe3ZhciBmPWQuZXhwYW5kbyxnPWIubm9kZVR5cGUsaD1nP2QuY2FjaGU6YixpPWc/Yltk
LmV4cGFuZG9dOmQuZXhwYW5kbztpZighaFtpXSlyZXR1cm47aWYoYyl7dmFyIGo9ZT9oW2ldW2Zd
OmhbaV07aWYoail7ZGVsZXRlIGpbY107aWYoIWQuaXNFbXB0eU9iamVjdChqKSlyZXR1cm59fWlm
KGUpe2RlbGV0ZSBoW2ldW2ZdO2lmKCFkLmlzRW1wdHlPYmplY3QoaFtpXSkpcmV0dXJufXZhciBr
PWhbaV1bZl07ZC5zdXBwb3J0LmRlbGV0ZUV4cGFuZG98fGghPWE/ZGVsZXRlIGhbaV06aFtpXT1u
dWxsLGs/KGhbaV09e30saFtpXVtmXT1rKTpnJiYoZC5zdXBwb3J0LmRlbGV0ZUV4cGFuZG8/ZGVs
ZXRlIGJbZC5leHBhbmRvXTpiLnJlbW92ZUF0dHJpYnV0ZT9iLnJlbW92ZUF0dHJpYnV0ZShkLmV4
cGFuZG8pOmJbZC5leHBhbmRvXT1udWxsKX19LF9kYXRhOmZ1bmN0aW9uKGEsYixjKXtyZXR1cm4g
ZC5kYXRhKGEsYixjLCEwKX0sYWNjZXB0RGF0YTpmdW5jdGlvbihhKXtpZihhLm5vZGVOYW1lKXt2
YXIgYj1kLm5vRGF0YVthLm5vZGVOYW1lLnRvTG93ZXJDYXNlKCldO2lmKGIpcmV0dXJuIGIhPT0h
MCYmYS5nZXRBdHRyaWJ1dGUoImNsYXNzaWQiKT09PWJ9cmV0dXJuITB9fSksZC5mbi5leHRlbmQo
e2RhdGE6ZnVuY3Rpb24oYSxjKXt2YXIgZT1udWxsO2lmKHR5cGVvZiBhPT09InVuZGVmaW5lZCIp
e2lmKHRoaXMubGVuZ3RoKXtlPWQuZGF0YSh0aGlzWzBdKTtpZih0aGlzWzBdLm5vZGVUeXBlPT09
MSl7dmFyIGc9dGhpc1swXS5hdHRyaWJ1dGVzLGg7Zm9yKHZhciBpPTAsaj1nLmxlbmd0aDtpPGo7
aSsrKWg9Z1tpXS5uYW1lLGguaW5kZXhPZigiZGF0YS0iKT09PTAmJihoPWguc3Vic3RyKDUpLGYo
dGhpc1swXSxoLGVbaF0pKX19cmV0dXJuIGV9aWYodHlwZW9mIGE9PT0ib2JqZWN0IilyZXR1cm4g
dGhpcy5lYWNoKGZ1bmN0aW9uKCl7ZC5kYXRhKHRoaXMsYSl9KTt2YXIgaz1hLnNwbGl0KCIuIik7
a1sxXT1rWzFdPyIuIitrWzFdOiIiO2lmKGM9PT1iKXtlPXRoaXMudHJpZ2dlckhhbmRsZXIoImdl
dERhdGEiK2tbMV0rIiEiLFtrWzBdXSksZT09PWImJnRoaXMubGVuZ3RoJiYoZT1kLmRhdGEodGhp
c1swXSxhKSxlPWYodGhpc1swXSxhLGUpKTtyZXR1cm4gZT09PWImJmtbMV0/dGhpcy5kYXRhKGtb
MF0pOmV9cmV0dXJuIHRoaXMuZWFjaChmdW5jdGlvbigpe3ZhciBiPWQodGhpcyksZT1ba1swXSxj
XTtiLnRyaWdnZXJIYW5kbGVyKCJzZXREYXRhIitrWzFdKyIhIixlKSxkLmRhdGEodGhpcyxhLGMp
LGIudHJpZ2dlckhhbmRsZXIoImNoYW5nZURhdGEiK2tbMV0rIiEiLGUpfSl9LHJlbW92ZURhdGE6
ZnVuY3Rpb24oYSl7cmV0dXJuIHRoaXMuZWFjaChmdW5jdGlvbigpe2QucmVtb3ZlRGF0YSh0aGlz
LGEpfSl9fSksZC5leHRlbmQoe3F1ZXVlOmZ1bmN0aW9uKGEsYixjKXtpZihhKXtiPShifHwiZngi
KSsicXVldWUiO3ZhciBlPWQuX2RhdGEoYSxiKTtpZighYylyZXR1cm4gZXx8W107IWV8fGQuaXNB
cnJheShjKT9lPWQuX2RhdGEoYSxiLGQubWFrZUFycmF5KGMpKTplLnB1c2goYyk7cmV0dXJuIGV9
fSxkZXF1ZXVlOmZ1bmN0aW9uKGEsYil7Yj1ifHwiZngiO3ZhciBjPWQucXVldWUoYSxiKSxlPWMu
c2hpZnQoKTtlPT09ImlucHJvZ3Jlc3MiJiYoZT1jLnNoaWZ0KCkpLGUmJihiPT09ImZ4IiYmYy51
bnNoaWZ0KCJpbnByb2dyZXNzIiksZS5jYWxsKGEsZnVuY3Rpb24oKXtkLmRlcXVldWUoYSxiKX0p
KSxjLmxlbmd0aHx8ZC5yZW1vdmVEYXRhKGEsYisicXVldWUiLCEwKX19KSxkLmZuLmV4dGVuZCh7
cXVldWU6ZnVuY3Rpb24oYSxjKXt0eXBlb2YgYSE9PSJzdHJpbmciJiYoYz1hLGE9ImZ4Iik7aWYo
Yz09PWIpcmV0dXJuIGQucXVldWUodGhpc1swXSxhKTtyZXR1cm4gdGhpcy5lYWNoKGZ1bmN0aW9u
KGIpe3ZhciBlPWQucXVldWUodGhpcyxhLGMpO2E9PT0iZngiJiZlWzBdIT09ImlucHJvZ3Jlc3Mi
JiZkLmRlcXVldWUodGhpcyxhKX0pfSxkZXF1ZXVlOmZ1bmN0aW9uKGEpe3JldHVybiB0aGlzLmVh
Y2goZnVuY3Rpb24oKXtkLmRlcXVldWUodGhpcyxhKX0pfSxkZWxheTpmdW5jdGlvbihhLGIpe2E9
ZC5meD9kLmZ4LnNwZWVkc1thXXx8YTphLGI9Ynx8ImZ4IjtyZXR1cm4gdGhpcy5xdWV1ZShiLGZ1
bmN0aW9uKCl7dmFyIGM9dGhpcztzZXRUaW1lb3V0KGZ1bmN0aW9uKCl7ZC5kZXF1ZXVlKGMsYil9
LGEpfSl9LGNsZWFyUXVldWU6ZnVuY3Rpb24oYSl7cmV0dXJuIHRoaXMucXVldWUoYXx8ImZ4Iixb
XSl9fSk7dmFyIGc9L1tcblx0XHJdL2csaD0vXHMrLyxpPS9cci9nLGo9L14oPzpocmVmfHNyY3xz
dHlsZSkkLyxrPS9eKD86YnV0dG9ufGlucHV0KSQvaSxsPS9eKD86YnV0dG9ufGlucHV0fG9iamVj
dHxzZWxlY3R8dGV4dGFyZWEpJC9pLG09L15hKD86cmVhKT8kL2ksbj0vXig/OnJhZGlvfGNoZWNr
Ym94KSQvaTtkLnByb3BzPXsiZm9yIjoiaHRtbEZvciIsImNsYXNzIjoiY2xhc3NOYW1lIixyZWFk
b25seToicmVhZE9ubHkiLG1heGxlbmd0aDoibWF4TGVuZ3RoIixjZWxsc3BhY2luZzoiY2VsbFNw
YWNpbmciLHJvd3NwYW46InJvd1NwYW4iLGNvbHNwYW46ImNvbFNwYW4iLHRhYmluZGV4OiJ0YWJJ
bmRleCIsdXNlbWFwOiJ1c2VNYXAiLGZyYW1lYm9yZGVyOiJmcmFtZUJvcmRlciJ9LGQuZm4uZXh0
ZW5kKHthdHRyOmZ1bmN0aW9uKGEsYil7cmV0dXJuIGQuYWNjZXNzKHRoaXMsYSxiLCEwLGQuYXR0
cil9LHJlbW92ZUF0dHI6ZnVuY3Rpb24oYSxiKXtyZXR1cm4gdGhpcy5lYWNoKGZ1bmN0aW9uKCl7
ZC5hdHRyKHRoaXMsYSwiIiksdGhpcy5ub2RlVHlwZT09PTEmJnRoaXMucmVtb3ZlQXR0cmlidXRl
KGEpfSl9LGFkZENsYXNzOmZ1bmN0aW9uKGEpe2lmKGQuaXNGdW5jdGlvbihhKSlyZXR1cm4gdGhp
cy5lYWNoKGZ1bmN0aW9uKGIpe3ZhciBjPWQodGhpcyk7Yy5hZGRDbGFzcyhhLmNhbGwodGhpcyxi
LGMuYXR0cigiY2xhc3MiKSkpfSk7aWYoYSYmdHlwZW9mIGE9PT0ic3RyaW5nIil7dmFyIGI9KGF8
fCIiKS5zcGxpdChoKTtmb3IodmFyIGM9MCxlPXRoaXMubGVuZ3RoO2M8ZTtjKyspe3ZhciBmPXRo
aXNbY107aWYoZi5ub2RlVHlwZT09PTEpaWYoZi5jbGFzc05hbWUpe3ZhciBnPSIgIitmLmNsYXNz
TmFtZSsiICIsaT1mLmNsYXNzTmFtZTtmb3IodmFyIGo9MCxrPWIubGVuZ3RoO2o8aztqKyspZy5p
bmRleE9mKCIgIitiW2pdKyIgIik8MCYmKGkrPSIgIitiW2pdKTtmLmNsYXNzTmFtZT1kLnRyaW0o
aSl9ZWxzZSBmLmNsYXNzTmFtZT1hfX1yZXR1cm4gdGhpc30scmVtb3ZlQ2xhc3M6ZnVuY3Rpb24o
YSl7aWYoZC5pc0Z1bmN0aW9uKGEpKXJldHVybiB0aGlzLmVhY2goZnVuY3Rpb24oYil7dmFyIGM9
ZCh0aGlzKTtjLnJlbW92ZUNsYXNzKGEuY2FsbCh0aGlzLGIsYy5hdHRyKCJjbGFzcyIpKSl9KTtp
ZihhJiZ0eXBlb2YgYT09PSJzdHJpbmcifHxhPT09Yil7dmFyIGM9KGF8fCIiKS5zcGxpdChoKTtm
b3IodmFyIGU9MCxmPXRoaXMubGVuZ3RoO2U8ZjtlKyspe3ZhciBpPXRoaXNbZV07aWYoaS5ub2Rl
VHlwZT09PTEmJmkuY2xhc3NOYW1lKWlmKGEpe3ZhciBqPSgiICIraS5jbGFzc05hbWUrIiAiKS5y
ZXBsYWNlKGcsIiAiKTtmb3IodmFyIGs9MCxsPWMubGVuZ3RoO2s8bDtrKyspaj1qLnJlcGxhY2Uo
IiAiK2Nba10rIiAiLCIgIik7aS5jbGFzc05hbWU9ZC50cmltKGopfWVsc2UgaS5jbGFzc05hbWU9
IiJ9fXJldHVybiB0aGlzfSx0b2dnbGVDbGFzczpmdW5jdGlvbihhLGIpe3ZhciBjPXR5cGVvZiBh
LGU9dHlwZW9mIGI9PT0iYm9vbGVhbiI7aWYoZC5pc0Z1bmN0aW9uKGEpKXJldHVybiB0aGlzLmVh
Y2goZnVuY3Rpb24oYyl7dmFyIGU9ZCh0aGlzKTtlLnRvZ2dsZUNsYXNzKGEuY2FsbCh0aGlzLGMs
ZS5hdHRyKCJjbGFzcyIpLGIpLGIpfSk7cmV0dXJuIHRoaXMuZWFjaChmdW5jdGlvbigpe2lmKGM9
PT0ic3RyaW5nIil7dmFyIGYsZz0wLGk9ZCh0aGlzKSxqPWIsaz1hLnNwbGl0KGgpO3doaWxlKGY9
a1tnKytdKWo9ZT9qOiFpLmhhc0NsYXNzKGYpLGlbaj8iYWRkQ2xhc3MiOiJyZW1vdmVDbGFzcyJd
KGYpfWVsc2UgaWYoYz09PSJ1bmRlZmluZWQifHxjPT09ImJvb2xlYW4iKXRoaXMuY2xhc3NOYW1l
JiZkLl9kYXRhKHRoaXMsIl9fY2xhc3NOYW1lX18iLHRoaXMuY2xhc3NOYW1lKSx0aGlzLmNsYXNz
TmFtZT10aGlzLmNsYXNzTmFtZXx8YT09PSExPyIiOmQuX2RhdGEodGhpcywiX19jbGFzc05hbWVf
XyIpfHwiIn0pfSxoYXNDbGFzczpmdW5jdGlvbihhKXt2YXIgYj0iICIrYSsiICI7Zm9yKHZhciBj
PTAsZD10aGlzLmxlbmd0aDtjPGQ7YysrKWlmKCgiICIrdGhpc1tjXS5jbGFzc05hbWUrIiAiKS5y
ZXBsYWNlKGcsIiAiKS5pbmRleE9mKGIpPi0xKXJldHVybiEwO3JldHVybiExfSx2YWw6ZnVuY3Rp
b24oYSl7aWYoIWFyZ3VtZW50cy5sZW5ndGgpe3ZhciBjPXRoaXNbMF07aWYoYyl7aWYoZC5ub2Rl
TmFtZShjLCJvcHRpb24iKSl7dmFyIGU9Yy5hdHRyaWJ1dGVzLnZhbHVlO3JldHVybiFlfHxlLnNw
ZWNpZmllZD9jLnZhbHVlOmMudGV4dH1pZihkLm5vZGVOYW1lKGMsInNlbGVjdCIpKXt2YXIgZj1j
LnNlbGVjdGVkSW5kZXgsZz1bXSxoPWMub3B0aW9ucyxqPWMudHlwZT09PSJzZWxlY3Qtb25lIjtp
ZihmPDApcmV0dXJuIG51bGw7Zm9yKHZhciBrPWo/ZjowLGw9aj9mKzE6aC5sZW5ndGg7azxsO2sr
Kyl7dmFyIG09aFtrXTtpZihtLnNlbGVjdGVkJiYoZC5zdXBwb3J0Lm9wdERpc2FibGVkPyFtLmRp
c2FibGVkOm0uZ2V0QXR0cmlidXRlKCJkaXNhYmxlZCIpPT09bnVsbCkmJighbS5wYXJlbnROb2Rl
LmRpc2FibGVkfHwhZC5ub2RlTmFtZShtLnBhcmVudE5vZGUsIm9wdGdyb3VwIikpKXthPWQobSku
dmFsKCk7aWYoailyZXR1cm4gYTtnLnB1c2goYSl9fXJldHVybiBnfWlmKG4udGVzdChjLnR5cGUp
JiYhZC5zdXBwb3J0LmNoZWNrT24pcmV0dXJuIGMuZ2V0QXR0cmlidXRlKCJ2YWx1ZSIpPT09bnVs
bD8ib24iOmMudmFsdWU7cmV0dXJuKGMudmFsdWV8fCIiKS5yZXBsYWNlKGksIiIpfXJldHVybiBi
fXZhciBvPWQuaXNGdW5jdGlvbihhKTtyZXR1cm4gdGhpcy5lYWNoKGZ1bmN0aW9uKGIpe3ZhciBj
PWQodGhpcyksZT1hO2lmKHRoaXMubm9kZVR5cGU9PT0xKXtvJiYoZT1hLmNhbGwodGhpcyxiLGMu
dmFsKCkpKSxlPT1udWxsP2U9IiI6dHlwZW9mIGU9PT0ibnVtYmVyIj9lKz0iIjpkLmlzQXJyYXko
ZSkmJihlPWQubWFwKGUsZnVuY3Rpb24oYSl7cmV0dXJuIGE9PW51bGw/IiI6YSsiIn0pKTtpZihk
LmlzQXJyYXkoZSkmJm4udGVzdCh0aGlzLnR5cGUpKXRoaXMuY2hlY2tlZD1kLmluQXJyYXkoYy52
YWwoKSxlKT49MDtlbHNlIGlmKGQubm9kZU5hbWUodGhpcywic2VsZWN0Iikpe3ZhciBmPWQubWFr
ZUFycmF5KGUpO2QoIm9wdGlvbiIsdGhpcykuZWFjaChmdW5jdGlvbigpe3RoaXMuc2VsZWN0ZWQ9
ZC5pbkFycmF5KGQodGhpcykudmFsKCksZik+PTB9KSxmLmxlbmd0aHx8KHRoaXMuc2VsZWN0ZWRJ
bmRleD0tMSl9ZWxzZSB0aGlzLnZhbHVlPWV9fSl9fSksZC5leHRlbmQoe2F0dHJGbjp7dmFsOiEw
LGNzczohMCxodG1sOiEwLHRleHQ6ITAsZGF0YTohMCx3aWR0aDohMCxoZWlnaHQ6ITAsb2Zmc2V0
OiEwfSxhdHRyOmZ1bmN0aW9uKGEsYyxlLGYpe2lmKCFhfHxhLm5vZGVUeXBlPT09M3x8YS5ub2Rl
VHlwZT09PTh8fGEubm9kZVR5cGU9PT0yKXJldHVybiBiO2lmKGYmJmMgaW4gZC5hdHRyRm4pcmV0
dXJuIGQoYSlbY10oZSk7dmFyIGc9YS5ub2RlVHlwZSE9PTF8fCFkLmlzWE1MRG9jKGEpLGg9ZSE9
PWI7Yz1nJiZkLnByb3BzW2NdfHxjO2lmKGEubm9kZVR5cGU9PT0xKXt2YXIgaT1qLnRlc3QoYyk7
aWYoYz09PSJzZWxlY3RlZCImJiFkLnN1cHBvcnQub3B0U2VsZWN0ZWQpe3ZhciBuPWEucGFyZW50
Tm9kZTtuJiYobi5zZWxlY3RlZEluZGV4LG4ucGFyZW50Tm9kZSYmbi5wYXJlbnROb2RlLnNlbGVj
dGVkSW5kZXgpfWlmKChjIGluIGF8fGFbY10hPT1iKSYmZyYmIWkpe2gmJihjPT09InR5cGUiJiZr
LnRlc3QoYS5ub2RlTmFtZSkmJmEucGFyZW50Tm9kZSYmZC5lcnJvcigidHlwZSBwcm9wZXJ0eSBj
YW4ndCBiZSBjaGFuZ2VkIiksZT09PW51bGw/YS5ub2RlVHlwZT09PTEmJmEucmVtb3ZlQXR0cmli
dXRlKGMpOmFbY109ZSk7aWYoZC5ub2RlTmFtZShhLCJmb3JtIikmJmEuZ2V0QXR0cmlidXRlTm9k
ZShjKSlyZXR1cm4gYS5nZXRBdHRyaWJ1dGVOb2RlKGMpLm5vZGVWYWx1ZTtpZihjPT09InRhYklu
ZGV4Iil7dmFyIG89YS5nZXRBdHRyaWJ1dGVOb2RlKCJ0YWJJbmRleCIpO3JldHVybiBvJiZvLnNw
ZWNpZmllZD9vLnZhbHVlOmwudGVzdChhLm5vZGVOYW1lKXx8bS50ZXN0KGEubm9kZU5hbWUpJiZh
LmhyZWY/MDpifXJldHVybiBhW2NdfWlmKCFkLnN1cHBvcnQuc3R5bGUmJmcmJmM9PT0ic3R5bGUi
KXtoJiYoYS5zdHlsZS5jc3NUZXh0PSIiK2UpO3JldHVybiBhLnN0eWxlLmNzc1RleHR9aCYmYS5z
ZXRBdHRyaWJ1dGUoYywiIitlKTtpZighYS5hdHRyaWJ1dGVzW2NdJiYoYS5oYXNBdHRyaWJ1dGUm
JiFhLmhhc0F0dHJpYnV0ZShjKSkpcmV0dXJuIGI7dmFyIHA9IWQuc3VwcG9ydC5ocmVmTm9ybWFs
aXplZCYmZyYmaT9hLmdldEF0dHJpYnV0ZShjLDIpOmEuZ2V0QXR0cmlidXRlKGMpO3JldHVybiBw
PT09bnVsbD9iOnB9aCYmKGFbY109ZSk7cmV0dXJuIGFbY119fSk7dmFyIG89L1wuKC4qKSQvLHA9
L14oPzp0ZXh0YXJlYXxpbnB1dHxzZWxlY3QpJC9pLHE9L1wuL2cscj0vIC9nLHM9L1teXHdccy58
YF0vZyx0PWZ1bmN0aW9uKGEpe3JldHVybiBhLnJlcGxhY2UocywiXFwkJiIpfSx1PSJldmVudHMi
O2QuZXZlbnQ9e2FkZDpmdW5jdGlvbihjLGUsZixnKXtpZihjLm5vZGVUeXBlIT09MyYmYy5ub2Rl
VHlwZSE9PTgpe2QuaXNXaW5kb3coYykmJihjIT09YSYmIWMuZnJhbWVFbGVtZW50KSYmKGM9YSk7
aWYoZj09PSExKWY9djtlbHNlIGlmKCFmKXJldHVybjt2YXIgaCxpO2YuaGFuZGxlciYmKGg9Zixm
PWguaGFuZGxlciksZi5ndWlkfHwoZi5ndWlkPWQuZ3VpZCsrKTt2YXIgaj1kLl9kYXRhKGMpO2lm
KCFqKXJldHVybjt2YXIgaz1qW3VdLGw9ai5oYW5kbGU7dHlwZW9mIGs9PT0iZnVuY3Rpb24iPyhs
PWsuaGFuZGxlLGs9ay5ldmVudHMpOmt8fChjLm5vZGVUeXBlfHwoalt1XT1qPWZ1bmN0aW9uKCl7
fSksai5ldmVudHM9az17fSksbHx8KGouaGFuZGxlPWw9ZnVuY3Rpb24oKXtyZXR1cm4gdHlwZW9m
IGQhPT0idW5kZWZpbmVkIiYmIWQuZXZlbnQudHJpZ2dlcmVkP2QuZXZlbnQuaGFuZGxlLmFwcGx5
KGwuZWxlbSxhcmd1bWVudHMpOmJ9KSxsLmVsZW09YyxlPWUuc3BsaXQoIiAiKTt2YXIgbSxuPTAs
bzt3aGlsZShtPWVbbisrXSl7aT1oP2QuZXh0ZW5kKHt9LGgpOntoYW5kbGVyOmYsZGF0YTpnfSxt
LmluZGV4T2YoIi4iKT4tMT8obz1tLnNwbGl0KCIuIiksbT1vLnNoaWZ0KCksaS5uYW1lc3BhY2U9
by5zbGljZSgwKS5zb3J0KCkuam9pbigiLiIpKToobz1bXSxpLm5hbWVzcGFjZT0iIiksaS50eXBl
PW0saS5ndWlkfHwoaS5ndWlkPWYuZ3VpZCk7dmFyIHA9a1ttXSxxPWQuZXZlbnQuc3BlY2lhbFtt
XXx8e307aWYoIXApe3A9a1ttXT1bXTtpZighcS5zZXR1cHx8cS5zZXR1cC5jYWxsKGMsZyxvLGwp
PT09ITEpYy5hZGRFdmVudExpc3RlbmVyP2MuYWRkRXZlbnRMaXN0ZW5lcihtLGwsITEpOmMuYXR0
YWNoRXZlbnQmJmMuYXR0YWNoRXZlbnQoIm9uIittLGwpfXEuYWRkJiYocS5hZGQuY2FsbChjLGkp
LGkuaGFuZGxlci5ndWlkfHwoaS5oYW5kbGVyLmd1aWQ9Zi5ndWlkKSkscC5wdXNoKGkpLGQuZXZl
bnQuZ2xvYmFsW21dPSEwfWM9bnVsbH19LGdsb2JhbDp7fSxyZW1vdmU6ZnVuY3Rpb24oYSxjLGUs
Zil7aWYoYS5ub2RlVHlwZSE9PTMmJmEubm9kZVR5cGUhPT04KXtlPT09ITEmJihlPXYpO3ZhciBn
LGgsaSxqLGs9MCxsLG0sbixvLHAscSxyLHM9ZC5oYXNEYXRhKGEpJiZkLl9kYXRhKGEpLHc9cyYm
c1t1XTtpZighc3x8IXcpcmV0dXJuO3R5cGVvZiB3PT09ImZ1bmN0aW9uIiYmKHM9dyx3PXcuZXZl
bnRzKSxjJiZjLnR5cGUmJihlPWMuaGFuZGxlcixjPWMudHlwZSk7aWYoIWN8fHR5cGVvZiBjPT09
InN0cmluZyImJmMuY2hhckF0KDApPT09Ii4iKXtjPWN8fCIiO2ZvcihoIGluIHcpZC5ldmVudC5y
ZW1vdmUoYSxoK2MpO3JldHVybn1jPWMuc3BsaXQoIiAiKTt3aGlsZShoPWNbaysrXSl7cj1oLHE9
bnVsbCxsPWguaW5kZXhPZigiLiIpPDAsbT1bXSxsfHwobT1oLnNwbGl0KCIuIiksaD1tLnNoaWZ0
KCksbj1uZXcgUmVnRXhwKCIoXnxcXC4pIitkLm1hcChtLnNsaWNlKDApLnNvcnQoKSx0KS5qb2lu
KCJcXC4oPzouKlxcLik/IikrIihcXC58JCkiKSkscD13W2hdO2lmKCFwKWNvbnRpbnVlO2lmKCFl
KXtmb3Ioaj0wO2o8cC5sZW5ndGg7aisrKXtxPXBbal07aWYobHx8bi50ZXN0KHEubmFtZXNwYWNl
KSlkLmV2ZW50LnJlbW92ZShhLHIscS5oYW5kbGVyLGopLHAuc3BsaWNlKGotLSwxKX1jb250aW51
ZX1vPWQuZXZlbnQuc3BlY2lhbFtoXXx8e307Zm9yKGo9Znx8MDtqPHAubGVuZ3RoO2orKyl7cT1w
W2pdO2lmKGUuZ3VpZD09PXEuZ3VpZCl7aWYobHx8bi50ZXN0KHEubmFtZXNwYWNlKSlmPT1udWxs
JiZwLnNwbGljZShqLS0sMSksby5yZW1vdmUmJm8ucmVtb3ZlLmNhbGwoYSxxKTtpZihmIT1udWxs
KWJyZWFrfX1pZihwLmxlbmd0aD09PTB8fGYhPW51bGwmJnAubGVuZ3RoPT09MSkoIW8udGVhcmRv
d258fG8udGVhcmRvd24uY2FsbChhLG0pPT09ITEpJiZkLnJlbW92ZUV2ZW50KGEsaCxzLmhhbmRs
ZSksZz1udWxsLGRlbGV0ZSB3W2hdfWlmKGQuaXNFbXB0eU9iamVjdCh3KSl7dmFyIHg9cy5oYW5k
bGU7eCYmKHguZWxlbT1udWxsKSxkZWxldGUgcy5ldmVudHMsZGVsZXRlIHMuaGFuZGxlLHR5cGVv
ZiBzPT09ImZ1bmN0aW9uIj9kLnJlbW92ZURhdGEoYSx1LCEwKTpkLmlzRW1wdHlPYmplY3Qocykm
JmQucmVtb3ZlRGF0YShhLGIsITApfX19LHRyaWdnZXI6ZnVuY3Rpb24oYSxjLGUpe3ZhciBmPWEu
dHlwZXx8YSxnPWFyZ3VtZW50c1szXTtpZighZyl7YT10eXBlb2YgYT09PSJvYmplY3QiP2FbZC5l
eHBhbmRvXT9hOmQuZXh0ZW5kKGQuRXZlbnQoZiksYSk6ZC5FdmVudChmKSxmLmluZGV4T2YoIiEi
KT49MCYmKGEudHlwZT1mPWYuc2xpY2UoMCwtMSksYS5leGNsdXNpdmU9ITApLGV8fChhLnN0b3BQ
cm9wYWdhdGlvbigpLGQuZXZlbnQuZ2xvYmFsW2ZdJiZkLmVhY2goZC5jYWNoZSxmdW5jdGlvbigp
e3ZhciBiPWQuZXhwYW5kbyxlPXRoaXNbYl07ZSYmZS5ldmVudHMmJmUuZXZlbnRzW2ZdJiZkLmV2
ZW50LnRyaWdnZXIoYSxjLGUuaGFuZGxlLmVsZW0pfSkpO2lmKCFlfHxlLm5vZGVUeXBlPT09M3x8
ZS5ub2RlVHlwZT09PTgpcmV0dXJuIGI7YS5yZXN1bHQ9YixhLnRhcmdldD1lLGM9ZC5tYWtlQXJy
YXkoYyksYy51bnNoaWZ0KGEpfWEuY3VycmVudFRhcmdldD1lO3ZhciBoPWUubm9kZVR5cGU/ZC5f
ZGF0YShlLCJoYW5kbGUiKTooZC5fZGF0YShlLHUpfHx7fSkuaGFuZGxlO2gmJmguYXBwbHkoZSxj
KTt2YXIgaT1lLnBhcmVudE5vZGV8fGUub3duZXJEb2N1bWVudDt0cnl7ZSYmZS5ub2RlTmFtZSYm
ZC5ub0RhdGFbZS5ub2RlTmFtZS50b0xvd2VyQ2FzZSgpXXx8ZVsib24iK2ZdJiZlWyJvbiIrZl0u
YXBwbHkoZSxjKT09PSExJiYoYS5yZXN1bHQ9ITEsYS5wcmV2ZW50RGVmYXVsdCgpKX1jYXRjaChq
KXt9aWYoIWEuaXNQcm9wYWdhdGlvblN0b3BwZWQoKSYmaSlkLmV2ZW50LnRyaWdnZXIoYSxjLGks
ITApO2Vsc2UgaWYoIWEuaXNEZWZhdWx0UHJldmVudGVkKCkpe3ZhciBrLGw9YS50YXJnZXQsbT1m
LnJlcGxhY2UobywiIiksbj1kLm5vZGVOYW1lKGwsImEiKSYmbT09PSJjbGljayIscD1kLmV2ZW50
LnNwZWNpYWxbbV18fHt9O2lmKCghcC5fZGVmYXVsdHx8cC5fZGVmYXVsdC5jYWxsKGUsYSk9PT0h
MSkmJiFuJiYhKGwmJmwubm9kZU5hbWUmJmQubm9EYXRhW2wubm9kZU5hbWUudG9Mb3dlckNhc2Uo
KV0pKXt0cnl7bFttXSYmKGs9bFsib24iK21dLGsmJihsWyJvbiIrbV09bnVsbCksZC5ldmVudC50
cmlnZ2VyZWQ9ITAsbFttXSgpKX1jYXRjaChxKXt9ayYmKGxbIm9uIittXT1rKSxkLmV2ZW50LnRy
aWdnZXJlZD0hMX19fSxoYW5kbGU6ZnVuY3Rpb24oYyl7dmFyIGUsZixnLGgsaSxqPVtdLGs9ZC5t
YWtlQXJyYXkoYXJndW1lbnRzKTtjPWtbMF09ZC5ldmVudC5maXgoY3x8YS5ldmVudCksYy5jdXJy
ZW50VGFyZ2V0PXRoaXMsZT1jLnR5cGUuaW5kZXhPZigiLiIpPDAmJiFjLmV4Y2x1c2l2ZSxlfHwo
Zz1jLnR5cGUuc3BsaXQoIi4iKSxjLnR5cGU9Zy5zaGlmdCgpLGo9Zy5zbGljZSgwKS5zb3J0KCks
aD1uZXcgUmVnRXhwKCIoXnxcXC4pIitqLmpvaW4oIlxcLig/Oi4qXFwuKT8iKSsiKFxcLnwkKSIp
KSxjLm5hbWVzcGFjZT1jLm5hbWVzcGFjZXx8ai5qb2luKCIuIiksaT1kLl9kYXRhKHRoaXMsdSks
dHlwZW9mIGk9PT0iZnVuY3Rpb24iJiYoaT1pLmV2ZW50cyksZj0oaXx8e30pW2MudHlwZV07aWYo
aSYmZil7Zj1mLnNsaWNlKDApO2Zvcih2YXIgbD0wLG09Zi5sZW5ndGg7bDxtO2wrKyl7dmFyIG49
ZltsXTtpZihlfHxoLnRlc3Qobi5uYW1lc3BhY2UpKXtjLmhhbmRsZXI9bi5oYW5kbGVyLGMuZGF0
YT1uLmRhdGEsYy5oYW5kbGVPYmo9bjt2YXIgbz1uLmhhbmRsZXIuYXBwbHkodGhpcyxrKTtvIT09
YiYmKGMucmVzdWx0PW8sbz09PSExJiYoYy5wcmV2ZW50RGVmYXVsdCgpLGMuc3RvcFByb3BhZ2F0
aW9uKCkpKTtpZihjLmlzSW1tZWRpYXRlUHJvcGFnYXRpb25TdG9wcGVkKCkpYnJlYWt9fX1yZXR1
cm4gYy5yZXN1bHR9LHByb3BzOiJhbHRLZXkgYXR0ckNoYW5nZSBhdHRyTmFtZSBidWJibGVzIGJ1
dHRvbiBjYW5jZWxhYmxlIGNoYXJDb2RlIGNsaWVudFggY2xpZW50WSBjdHJsS2V5IGN1cnJlbnRU
YXJnZXQgZGF0YSBkZXRhaWwgZXZlbnRQaGFzZSBmcm9tRWxlbWVudCBoYW5kbGVyIGtleUNvZGUg
bGF5ZXJYIGxheWVyWSBtZXRhS2V5IG5ld1ZhbHVlIG9mZnNldFggb2Zmc2V0WSBwYWdlWCBwYWdl
WSBwcmV2VmFsdWUgcmVsYXRlZE5vZGUgcmVsYXRlZFRhcmdldCBzY3JlZW5YIHNjcmVlblkgc2hp
ZnRLZXkgc3JjRWxlbWVudCB0YXJnZXQgdG9FbGVtZW50IHZpZXcgd2hlZWxEZWx0YSB3aGljaCIu
c3BsaXQoIiAiKSxmaXg6ZnVuY3Rpb24oYSl7aWYoYVtkLmV4cGFuZG9dKXJldHVybiBhO3ZhciBl
PWE7YT1kLkV2ZW50KGUpO2Zvcih2YXIgZj10aGlzLnByb3BzLmxlbmd0aCxnO2Y7KWc9dGhpcy5w
cm9wc1stLWZdLGFbZ109ZVtnXTthLnRhcmdldHx8KGEudGFyZ2V0PWEuc3JjRWxlbWVudHx8Yyks
YS50YXJnZXQubm9kZVR5cGU9PT0zJiYoYS50YXJnZXQ9YS50YXJnZXQucGFyZW50Tm9kZSksIWEu
cmVsYXRlZFRhcmdldCYmYS5mcm9tRWxlbWVudCYmKGEucmVsYXRlZFRhcmdldD1hLmZyb21FbGVt
ZW50PT09YS50YXJnZXQ/YS50b0VsZW1lbnQ6YS5mcm9tRWxlbWVudCk7aWYoYS5wYWdlWD09bnVs
bCYmYS5jbGllbnRYIT1udWxsKXt2YXIgaD1jLmRvY3VtZW50RWxlbWVudCxpPWMuYm9keTthLnBh
Z2VYPWEuY2xpZW50WCsoaCYmaC5zY3JvbGxMZWZ0fHxpJiZpLnNjcm9sbExlZnR8fDApLShoJiZo
LmNsaWVudExlZnR8fGkmJmkuY2xpZW50TGVmdHx8MCksYS5wYWdlWT1hLmNsaWVudFkrKGgmJmgu
c2Nyb2xsVG9wfHxpJiZpLnNjcm9sbFRvcHx8MCktKGgmJmguY2xpZW50VG9wfHxpJiZpLmNsaWVu
dFRvcHx8MCl9YS53aGljaD09bnVsbCYmKGEuY2hhckNvZGUhPW51bGx8fGEua2V5Q29kZSE9bnVs
bCkmJihhLndoaWNoPWEuY2hhckNvZGUhPW51bGw/YS5jaGFyQ29kZTphLmtleUNvZGUpLCFhLm1l
dGFLZXkmJmEuY3RybEtleSYmKGEubWV0YUtleT1hLmN0cmxLZXkpLCFhLndoaWNoJiZhLmJ1dHRv
biE9PWImJihhLndoaWNoPWEuYnV0dG9uJjE/MTphLmJ1dHRvbiYyPzM6YS5idXR0b24mND8yOjAp
O3JldHVybiBhfSxndWlkOjFlOCxwcm94eTpkLnByb3h5LHNwZWNpYWw6e3JlYWR5OntzZXR1cDpk
LmJpbmRSZWFkeSx0ZWFyZG93bjpkLm5vb3B9LGxpdmU6e2FkZDpmdW5jdGlvbihhKXtkLmV2ZW50
LmFkZCh0aGlzLEYoYS5vcmlnVHlwZSxhLnNlbGVjdG9yKSxkLmV4dGVuZCh7fSxhLHtoYW5kbGVy
OkUsZ3VpZDphLmhhbmRsZXIuZ3VpZH0pKX0scmVtb3ZlOmZ1bmN0aW9uKGEpe2QuZXZlbnQucmVt
b3ZlKHRoaXMsRihhLm9yaWdUeXBlLGEuc2VsZWN0b3IpLGEpfX0sYmVmb3JldW5sb2FkOntzZXR1
cDpmdW5jdGlvbihhLGIsYyl7ZC5pc1dpbmRvdyh0aGlzKSYmKHRoaXMub25iZWZvcmV1bmxvYWQ9
Yyl9LHRlYXJkb3duOmZ1bmN0aW9uKGEsYil7dGhpcy5vbmJlZm9yZXVubG9hZD09PWImJih0aGlz
Lm9uYmVmb3JldW5sb2FkPW51bGwpfX19fSxkLnJlbW92ZUV2ZW50PWMucmVtb3ZlRXZlbnRMaXN0
ZW5lcj9mdW5jdGlvbihhLGIsYyl7YS5yZW1vdmVFdmVudExpc3RlbmVyJiZhLnJlbW92ZUV2ZW50
TGlzdGVuZXIoYixjLCExKX06ZnVuY3Rpb24oYSxiLGMpe2EuZGV0YWNoRXZlbnQmJmEuZGV0YWNo
RXZlbnQoIm9uIitiLGMpfSxkLkV2ZW50PWZ1bmN0aW9uKGEpe2lmKCF0aGlzLnByZXZlbnREZWZh
dWx0KXJldHVybiBuZXcgZC5FdmVudChhKTthJiZhLnR5cGU/KHRoaXMub3JpZ2luYWxFdmVudD1h
LHRoaXMudHlwZT1hLnR5cGUsdGhpcy5pc0RlZmF1bHRQcmV2ZW50ZWQ9YS5kZWZhdWx0UHJldmVu
dGVkfHxhLnJldHVyblZhbHVlPT09ITF8fGEuZ2V0UHJldmVudERlZmF1bHQmJmEuZ2V0UHJldmVu
dERlZmF1bHQoKT93OnYpOnRoaXMudHlwZT1hLHRoaXMudGltZVN0YW1wPWQubm93KCksdGhpc1tk
LmV4cGFuZG9dPSEwfSxkLkV2ZW50LnByb3RvdHlwZT17cHJldmVudERlZmF1bHQ6ZnVuY3Rpb24o
KXt0aGlzLmlzRGVmYXVsdFByZXZlbnRlZD13O3ZhciBhPXRoaXMub3JpZ2luYWxFdmVudDthJiYo
YS5wcmV2ZW50RGVmYXVsdD9hLnByZXZlbnREZWZhdWx0KCk6YS5yZXR1cm5WYWx1ZT0hMSl9LHN0
b3BQcm9wYWdhdGlvbjpmdW5jdGlvbigpe3RoaXMuaXNQcm9wYWdhdGlvblN0b3BwZWQ9dzt2YXIg
YT10aGlzLm9yaWdpbmFsRXZlbnQ7YSYmKGEuc3RvcFByb3BhZ2F0aW9uJiZhLnN0b3BQcm9wYWdh
dGlvbigpLGEuY2FuY2VsQnViYmxlPSEwKX0sc3RvcEltbWVkaWF0ZVByb3BhZ2F0aW9uOmZ1bmN0
aW9uKCl7dGhpcy5pc0ltbWVkaWF0ZVByb3BhZ2F0aW9uU3RvcHBlZD13LHRoaXMuc3RvcFByb3Bh
Z2F0aW9uKCl9LGlzRGVmYXVsdFByZXZlbnRlZDp2LGlzUHJvcGFnYXRpb25TdG9wcGVkOnYsaXNJ
bW1lZGlhdGVQcm9wYWdhdGlvblN0b3BwZWQ6dn07dmFyIHg9ZnVuY3Rpb24oYSl7dmFyIGI9YS5y
ZWxhdGVkVGFyZ2V0O3RyeXt3aGlsZShiJiZiIT09dGhpcyliPWIucGFyZW50Tm9kZTtiIT09dGhp
cyYmKGEudHlwZT1hLmRhdGEsZC5ldmVudC5oYW5kbGUuYXBwbHkodGhpcyxhcmd1bWVudHMpKX1j
YXRjaChjKXt9fSx5PWZ1bmN0aW9uKGEpe2EudHlwZT1hLmRhdGEsZC5ldmVudC5oYW5kbGUuYXBw
bHkodGhpcyxhcmd1bWVudHMpfTtkLmVhY2goe21vdXNlZW50ZXI6Im1vdXNlb3ZlciIsbW91c2Vs
ZWF2ZToibW91c2VvdXQifSxmdW5jdGlvbihhLGIpe2QuZXZlbnQuc3BlY2lhbFthXT17c2V0dXA6
ZnVuY3Rpb24oYyl7ZC5ldmVudC5hZGQodGhpcyxiLGMmJmMuc2VsZWN0b3I/eTp4LGEpfSx0ZWFy
ZG93bjpmdW5jdGlvbihhKXtkLmV2ZW50LnJlbW92ZSh0aGlzLGIsYSYmYS5zZWxlY3Rvcj95Ongp
fX19KSxkLnN1cHBvcnQuc3VibWl0QnViYmxlc3x8KGQuZXZlbnQuc3BlY2lhbC5zdWJtaXQ9e3Nl
dHVwOmZ1bmN0aW9uKGEsYyl7aWYodGhpcy5ub2RlTmFtZSYmdGhpcy5ub2RlTmFtZS50b0xvd2Vy
Q2FzZSgpIT09ImZvcm0iKWQuZXZlbnQuYWRkKHRoaXMsImNsaWNrLnNwZWNpYWxTdWJtaXQiLGZ1
bmN0aW9uKGEpe3ZhciBjPWEudGFyZ2V0LGU9Yy50eXBlO2lmKChlPT09InN1Ym1pdCJ8fGU9PT0i
aW1hZ2UiKSYmZChjKS5jbG9zZXN0KCJmb3JtIikubGVuZ3RoKXthLmxpdmVGaXJlZD1iO3JldHVy
biBDKCJzdWJtaXQiLHRoaXMsYXJndW1lbnRzKX19KSxkLmV2ZW50LmFkZCh0aGlzLCJrZXlwcmVz
cy5zcGVjaWFsU3VibWl0IixmdW5jdGlvbihhKXt2YXIgYz1hLnRhcmdldCxlPWMudHlwZTtpZigo
ZT09PSJ0ZXh0Inx8ZT09PSJwYXNzd29yZCIpJiZkKGMpLmNsb3Nlc3QoImZvcm0iKS5sZW5ndGgm
JmEua2V5Q29kZT09PTEzKXthLmxpdmVGaXJlZD1iO3JldHVybiBDKCJzdWJtaXQiLHRoaXMsYXJn
dW1lbnRzKX19KTtlbHNlIHJldHVybiExfSx0ZWFyZG93bjpmdW5jdGlvbihhKXtkLmV2ZW50LnJl
bW92ZSh0aGlzLCIuc3BlY2lhbFN1Ym1pdCIpfX0pO2lmKCFkLnN1cHBvcnQuY2hhbmdlQnViYmxl
cyl7dmFyIHosQT1mdW5jdGlvbihhKXt2YXIgYj1hLnR5cGUsYz1hLnZhbHVlO2I9PT0icmFkaW8i
fHxiPT09ImNoZWNrYm94Ij9jPWEuY2hlY2tlZDpiPT09InNlbGVjdC1tdWx0aXBsZSI/Yz1hLnNl
bGVjdGVkSW5kZXg+LTE/ZC5tYXAoYS5vcHRpb25zLGZ1bmN0aW9uKGEpe3JldHVybiBhLnNlbGVj
dGVkfSkuam9pbigiLSIpOiIiOmEubm9kZU5hbWUudG9Mb3dlckNhc2UoKT09PSJzZWxlY3QiJiYo
Yz1hLnNlbGVjdGVkSW5kZXgpO3JldHVybiBjfSxCPWZ1bmN0aW9uIEIoYSl7dmFyIGM9YS50YXJn
ZXQsZSxmO2lmKHAudGVzdChjLm5vZGVOYW1lKSYmIWMucmVhZE9ubHkpe2U9ZC5fZGF0YShjLCJf
Y2hhbmdlX2RhdGEiKSxmPUEoYyksKGEudHlwZSE9PSJmb2N1c291dCJ8fGMudHlwZSE9PSJyYWRp
byIpJiZkLl9kYXRhKGMsIl9jaGFuZ2VfZGF0YSIsZik7aWYoZT09PWJ8fGY9PT1lKXJldHVybjtp
ZihlIT1udWxsfHxmKXthLnR5cGU9ImNoYW5nZSIsYS5saXZlRmlyZWQ9YjtyZXR1cm4gZC5ldmVu
dC50cmlnZ2VyKGEsYXJndW1lbnRzWzFdLGMpfX19O2QuZXZlbnQuc3BlY2lhbC5jaGFuZ2U9e2Zp
bHRlcnM6e2ZvY3Vzb3V0OkIsYmVmb3JlZGVhY3RpdmF0ZTpCLGNsaWNrOmZ1bmN0aW9uKGEpe3Zh
ciBiPWEudGFyZ2V0LGM9Yi50eXBlO2lmKGM9PT0icmFkaW8ifHxjPT09ImNoZWNrYm94Inx8Yi5u
b2RlTmFtZS50b0xvd2VyQ2FzZSgpPT09InNlbGVjdCIpcmV0dXJuIEIuY2FsbCh0aGlzLGEpfSxr
ZXlkb3duOmZ1bmN0aW9uKGEpe3ZhciBiPWEudGFyZ2V0LGM9Yi50eXBlO2lmKGEua2V5Q29kZT09
PTEzJiZiLm5vZGVOYW1lLnRvTG93ZXJDYXNlKCkhPT0idGV4dGFyZWEifHxhLmtleUNvZGU9PT0z
MiYmKGM9PT0iY2hlY2tib3gifHxjPT09InJhZGlvIil8fGM9PT0ic2VsZWN0LW11bHRpcGxlIily
ZXR1cm4gQi5jYWxsKHRoaXMsYSl9LGJlZm9yZWFjdGl2YXRlOmZ1bmN0aW9uKGEpe3ZhciBiPWEu
dGFyZ2V0O2QuX2RhdGEoYiwiX2NoYW5nZV9kYXRhIixBKGIpKX19LHNldHVwOmZ1bmN0aW9uKGEs
Yil7aWYodGhpcy50eXBlPT09ImZpbGUiKXJldHVybiExO2Zvcih2YXIgYyBpbiB6KWQuZXZlbnQu
YWRkKHRoaXMsYysiLnNwZWNpYWxDaGFuZ2UiLHpbY10pO3JldHVybiBwLnRlc3QodGhpcy5ub2Rl
TmFtZSl9LHRlYXJkb3duOmZ1bmN0aW9uKGEpe2QuZXZlbnQucmVtb3ZlKHRoaXMsIi5zcGVjaWFs
Q2hhbmdlIik7cmV0dXJuIHAudGVzdCh0aGlzLm5vZGVOYW1lKX19LHo9ZC5ldmVudC5zcGVjaWFs
LmNoYW5nZS5maWx0ZXJzLHouZm9jdXM9ei5iZWZvcmVhY3RpdmF0ZX1jLmFkZEV2ZW50TGlzdGVu
ZXImJmQuZWFjaCh7Zm9jdXM6ImZvY3VzaW4iLGJsdXI6ImZvY3Vzb3V0In0sZnVuY3Rpb24oYSxi
KXtmdW5jdGlvbiBjKGEpe2E9ZC5ldmVudC5maXgoYSksYS50eXBlPWI7cmV0dXJuIGQuZXZlbnQu
aGFuZGxlLmNhbGwodGhpcyxhKX1kLmV2ZW50LnNwZWNpYWxbYl09e3NldHVwOmZ1bmN0aW9uKCl7
dGhpcy5hZGRFdmVudExpc3RlbmVyKGEsYywhMCl9LHRlYXJkb3duOmZ1bmN0aW9uKCl7dGhpcy5y
ZW1vdmVFdmVudExpc3RlbmVyKGEsYywhMCl9fX0pLGQuZWFjaChbImJpbmQiLCJvbmUiXSxmdW5j
dGlvbihhLGMpe2QuZm5bY109ZnVuY3Rpb24oYSxlLGYpe2lmKHR5cGVvZiBhPT09Im9iamVjdCIp
e2Zvcih2YXIgZyBpbiBhKXRoaXNbY10oZyxlLGFbZ10sZik7cmV0dXJuIHRoaXN9aWYoZC5pc0Z1
bmN0aW9uKGUpfHxlPT09ITEpZj1lLGU9Yjt2YXIgaD1jPT09Im9uZSI/ZC5wcm94eShmLGZ1bmN0
aW9uKGEpe2QodGhpcykudW5iaW5kKGEsaCk7cmV0dXJuIGYuYXBwbHkodGhpcyxhcmd1bWVudHMp
fSk6ZjtpZihhPT09InVubG9hZCImJmMhPT0ib25lIil0aGlzLm9uZShhLGUsZik7ZWxzZSBmb3Io
dmFyIGk9MCxqPXRoaXMubGVuZ3RoO2k8ajtpKyspZC5ldmVudC5hZGQodGhpc1tpXSxhLGgsZSk7
cmV0dXJuIHRoaXN9fSksZC5mbi5leHRlbmQoe3VuYmluZDpmdW5jdGlvbihhLGIpe2lmKHR5cGVv
ZiBhIT09Im9iamVjdCJ8fGEucHJldmVudERlZmF1bHQpZm9yKHZhciBlPTAsZj10aGlzLmxlbmd0
aDtlPGY7ZSsrKWQuZXZlbnQucmVtb3ZlKHRoaXNbZV0sYSxiKTtlbHNlIGZvcih2YXIgYyBpbiBh
KXRoaXMudW5iaW5kKGMsYVtjXSk7cmV0dXJuIHRoaXN9LGRlbGVnYXRlOmZ1bmN0aW9uKGEsYixj
LGQpe3JldHVybiB0aGlzLmxpdmUoYixjLGQsYSl9LHVuZGVsZWdhdGU6ZnVuY3Rpb24oYSxiLGMp
e3JldHVybiBhcmd1bWVudHMubGVuZ3RoPT09MD90aGlzLnVuYmluZCgibGl2ZSIpOnRoaXMuZGll
KGIsbnVsbCxjLGEpfSx0cmlnZ2VyOmZ1bmN0aW9uKGEsYil7cmV0dXJuIHRoaXMuZWFjaChmdW5j
dGlvbigpe2QuZXZlbnQudHJpZ2dlcihhLGIsdGhpcyl9KX0sdHJpZ2dlckhhbmRsZXI6ZnVuY3Rp
b24oYSxiKXtpZih0aGlzWzBdKXt2YXIgYz1kLkV2ZW50KGEpO2MucHJldmVudERlZmF1bHQoKSxj
LnN0b3BQcm9wYWdhdGlvbigpLGQuZXZlbnQudHJpZ2dlcihjLGIsdGhpc1swXSk7cmV0dXJuIGMu
cmVzdWx0fX0sdG9nZ2xlOmZ1bmN0aW9uKGEpe3ZhciBiPWFyZ3VtZW50cyxjPTE7d2hpbGUoYzxi
Lmxlbmd0aClkLnByb3h5KGEsYltjKytdKTtyZXR1cm4gdGhpcy5jbGljayhkLnByb3h5KGEsZnVu
Y3Rpb24oZSl7dmFyIGY9KGQuX2RhdGEodGhpcywibGFzdFRvZ2dsZSIrYS5ndWlkKXx8MCklYztk
Ll9kYXRhKHRoaXMsImxhc3RUb2dnbGUiK2EuZ3VpZCxmKzEpLGUucHJldmVudERlZmF1bHQoKTty
ZXR1cm4gYltmXS5hcHBseSh0aGlzLGFyZ3VtZW50cyl8fCExfSkpfSxob3ZlcjpmdW5jdGlvbihh
LGIpe3JldHVybiB0aGlzLm1vdXNlZW50ZXIoYSkubW91c2VsZWF2ZShifHxhKX19KTt2YXIgRD17
Zm9jdXM6ImZvY3VzaW4iLGJsdXI6ImZvY3Vzb3V0Iixtb3VzZWVudGVyOiJtb3VzZW92ZXIiLG1v
dXNlbGVhdmU6Im1vdXNlb3V0In07ZC5lYWNoKFsibGl2ZSIsImRpZSJdLGZ1bmN0aW9uKGEsYyl7
ZC5mbltjXT1mdW5jdGlvbihhLGUsZixnKXt2YXIgaCxpPTAsaixrLGwsbT1nfHx0aGlzLnNlbGVj
dG9yLG49Zz90aGlzOmQodGhpcy5jb250ZXh0KTtpZih0eXBlb2YgYT09PSJvYmplY3QiJiYhYS5w
cmV2ZW50RGVmYXVsdCl7Zm9yKHZhciBwIGluIGEpbltjXShwLGUsYVtwXSxtKTtyZXR1cm4gdGhp
c31kLmlzRnVuY3Rpb24oZSkmJihmPWUsZT1iKSxhPShhfHwiIikuc3BsaXQoIiAiKTt3aGlsZSgo
aD1hW2krK10pIT1udWxsKXtqPW8uZXhlYyhoKSxrPSIiLGomJihrPWpbMF0saD1oLnJlcGxhY2Uo
bywiIikpO2lmKGg9PT0iaG92ZXIiKXthLnB1c2goIm1vdXNlZW50ZXIiK2ssIm1vdXNlbGVhdmUi
K2spO2NvbnRpbnVlfWw9aCxoPT09ImZvY3VzInx8aD09PSJibHVyIj8oYS5wdXNoKERbaF0rayks
aD1oK2spOmg9KERbaF18fGgpK2s7aWYoYz09PSJsaXZlIilmb3IodmFyIHE9MCxyPW4ubGVuZ3Ro
O3E8cjtxKyspZC5ldmVudC5hZGQobltxXSwibGl2ZS4iK0YoaCxtKSx7ZGF0YTplLHNlbGVjdG9y
Om0saGFuZGxlcjpmLG9yaWdUeXBlOmgsb3JpZ0hhbmRsZXI6ZixwcmVUeXBlOmx9KTtlbHNlIG4u
dW5iaW5kKCJsaXZlLiIrRihoLG0pLGYpfXJldHVybiB0aGlzfX0pLGQuZWFjaCgiYmx1ciBmb2N1
cyBmb2N1c2luIGZvY3Vzb3V0IGxvYWQgcmVzaXplIHNjcm9sbCB1bmxvYWQgY2xpY2sgZGJsY2xp
Y2sgbW91c2Vkb3duIG1vdXNldXAgbW91c2Vtb3ZlIG1vdXNlb3ZlciBtb3VzZW91dCBtb3VzZWVu
dGVyIG1vdXNlbGVhdmUgY2hhbmdlIHNlbGVjdCBzdWJtaXQga2V5ZG93biBrZXlwcmVzcyBrZXl1
cCBlcnJvciIuc3BsaXQoIiAiKSxmdW5jdGlvbihhLGIpe2QuZm5bYl09ZnVuY3Rpb24oYSxjKXtj
PT1udWxsJiYoYz1hLGE9bnVsbCk7cmV0dXJuIGFyZ3VtZW50cy5sZW5ndGg+MD90aGlzLmJpbmQo
YixhLGMpOnRoaXMudHJpZ2dlcihiKX0sZC5hdHRyRm4mJihkLmF0dHJGbltiXT0hMCl9KSxmdW5j
dGlvbigpe2Z1bmN0aW9uIHMoYSxiLGMsZCxlLGYpe2Zvcih2YXIgZz0wLGg9ZC5sZW5ndGg7Zzxo
O2crKyl7dmFyIGo9ZFtnXTtpZihqKXt2YXIgaz0hMTtqPWpbYV07d2hpbGUoail7aWYoai5zaXpj
YWNoZT09PWMpe2s9ZFtqLnNpenNldF07YnJlYWt9aWYoai5ub2RlVHlwZT09PTEpe2Z8fChqLnNp
emNhY2hlPWMsai5zaXpzZXQ9Zyk7aWYodHlwZW9mIGIhPT0ic3RyaW5nIil7aWYoaj09PWIpe2s9
ITA7YnJlYWt9fWVsc2UgaWYoaS5maWx0ZXIoYixbal0pLmxlbmd0aD4wKXtrPWo7YnJlYWt9fWo9
althXX1kW2ddPWt9fX1mdW5jdGlvbiByKGEsYixjLGQsZSxmKXtmb3IodmFyIGc9MCxoPWQubGVu
Z3RoO2c8aDtnKyspe3ZhciBpPWRbZ107aWYoaSl7dmFyIGo9ITE7aT1pW2FdO3doaWxlKGkpe2lm
KGkuc2l6Y2FjaGU9PT1jKXtqPWRbaS5zaXpzZXRdO2JyZWFrfWkubm9kZVR5cGU9PT0xJiYhZiYm
KGkuc2l6Y2FjaGU9YyxpLnNpenNldD1nKTtpZihpLm5vZGVOYW1lLnRvTG93ZXJDYXNlKCk9PT1i
KXtqPWk7YnJlYWt9aT1pW2FdfWRbZ109an19fXZhciBhPS8oKD86XCgoPzpcKFteKCldK1wpfFte
KCldKykrXCl8XFsoPzpcW1teXFtcXV0qXF18WyciXVteJyJdKlsnIl18W15cW1xdJyJdKykrXF18
XFwufFteID4rfiwoXFtcXF0rKSt8Wz4rfl0pKFxzKixccyopPygoPzoufFxyfFxuKSopL2csZT0w
LGY9T2JqZWN0LnByb3RvdHlwZS50b1N0cmluZyxnPSExLGg9ITA7WzAsMF0uc29ydChmdW5jdGlv
bigpe2g9ITE7cmV0dXJuIDB9KTt2YXIgaT1mdW5jdGlvbihiLGQsZSxnKXtlPWV8fFtdLGQ9ZHx8
Yzt2YXIgaD1kO2lmKGQubm9kZVR5cGUhPT0xJiZkLm5vZGVUeXBlIT09OSlyZXR1cm5bXTtpZigh
Ynx8dHlwZW9mIGIhPT0ic3RyaW5nIilyZXR1cm4gZTt2YXIgbCxtLG8scCxxLHIscyx1LHY9ITAs
dz1pLmlzWE1MKGQpLHg9W10seT1iO2Rve2EuZXhlYygiIiksbD1hLmV4ZWMoeSk7aWYobCl7eT1s
WzNdLHgucHVzaChsWzFdKTtpZihsWzJdKXtwPWxbM107YnJlYWt9fX13aGlsZShsKTtpZih4Lmxl
bmd0aD4xJiZrLmV4ZWMoYikpaWYoeC5sZW5ndGg9PT0yJiZqLnJlbGF0aXZlW3hbMF1dKW09dCh4
WzBdK3hbMV0sZCk7ZWxzZXttPWoucmVsYXRpdmVbeFswXV0/W2RdOmkoeC5zaGlmdCgpLGQpO3do
aWxlKHgubGVuZ3RoKWI9eC5zaGlmdCgpLGoucmVsYXRpdmVbYl0mJihiKz14LnNoaWZ0KCkpLG09
dChiLG0pfWVsc2V7IWcmJngubGVuZ3RoPjEmJmQubm9kZVR5cGU9PT05JiYhdyYmai5tYXRjaC5J
RC50ZXN0KHhbMF0pJiYhai5tYXRjaC5JRC50ZXN0KHhbeC5sZW5ndGgtMV0pJiYocT1pLmZpbmQo
eC5zaGlmdCgpLGQsdyksZD1xLmV4cHI/aS5maWx0ZXIocS5leHByLHEuc2V0KVswXTpxLnNldFsw
XSk7aWYoZCl7cT1nP3tleHByOngucG9wKCksc2V0Om4oZyl9OmkuZmluZCh4LnBvcCgpLHgubGVu
Z3RoPT09MSYmKHhbMF09PT0ifiJ8fHhbMF09PT0iKyIpJiZkLnBhcmVudE5vZGU/ZC5wYXJlbnRO
b2RlOmQsdyksbT1xLmV4cHI/aS5maWx0ZXIocS5leHByLHEuc2V0KTpxLnNldCx4Lmxlbmd0aD4w
P289bihtKTp2PSExO3doaWxlKHgubGVuZ3RoKXI9eC5wb3AoKSxzPXIsai5yZWxhdGl2ZVtyXT9z
PXgucG9wKCk6cj0iIixzPT1udWxsJiYocz1kKSxqLnJlbGF0aXZlW3JdKG8scyx3KX1lbHNlIG89
eD1bXX1vfHwobz1tKSxvfHxpLmVycm9yKHJ8fGIpO2lmKGYuY2FsbChvKT09PSJbb2JqZWN0IEFy
cmF5XSIpaWYodilpZihkJiZkLm5vZGVUeXBlPT09MSlmb3IodT0wO29bdV0hPW51bGw7dSsrKW9b
dV0mJihvW3VdPT09ITB8fG9bdV0ubm9kZVR5cGU9PT0xJiZpLmNvbnRhaW5zKGQsb1t1XSkpJiZl
LnB1c2gobVt1XSk7ZWxzZSBmb3IodT0wO29bdV0hPW51bGw7dSsrKW9bdV0mJm9bdV0ubm9kZVR5
cGU9PT0xJiZlLnB1c2gobVt1XSk7ZWxzZSBlLnB1c2guYXBwbHkoZSxvKTtlbHNlIG4obyxlKTtw
JiYoaShwLGgsZSxnKSxpLnVuaXF1ZVNvcnQoZSkpO3JldHVybiBlfTtpLnVuaXF1ZVNvcnQ9ZnVu
Y3Rpb24oYSl7aWYocCl7Zz1oLGEuc29ydChwKTtpZihnKWZvcih2YXIgYj0xO2I8YS5sZW5ndGg7
YisrKWFbYl09PT1hW2ItMV0mJmEuc3BsaWNlKGItLSwxKX1yZXR1cm4gYX0saS5tYXRjaGVzPWZ1
bmN0aW9uKGEsYil7cmV0dXJuIGkoYSxudWxsLG51bGwsYil9LGkubWF0Y2hlc1NlbGVjdG9yPWZ1
bmN0aW9uKGEsYil7cmV0dXJuIGkoYixudWxsLG51bGwsW2FdKS5sZW5ndGg+MH0saS5maW5kPWZ1
bmN0aW9uKGEsYixjKXt2YXIgZDtpZighYSlyZXR1cm5bXTtmb3IodmFyIGU9MCxmPWoub3JkZXIu
bGVuZ3RoO2U8ZjtlKyspe3ZhciBnLGg9ai5vcmRlcltlXTtpZihnPWoubGVmdE1hdGNoW2hdLmV4
ZWMoYSkpe3ZhciBpPWdbMV07Zy5zcGxpY2UoMSwxKTtpZihpLnN1YnN0cihpLmxlbmd0aC0xKSE9
PSJcXCIpe2dbMV09KGdbMV18fCIiKS5yZXBsYWNlKC9cXC9nLCIiKSxkPWouZmluZFtoXShnLGIs
Yyk7aWYoZCE9bnVsbCl7YT1hLnJlcGxhY2Uoai5tYXRjaFtoXSwiIik7YnJlYWt9fX19ZHx8KGQ9
dHlwZW9mIGIuZ2V0RWxlbWVudHNCeVRhZ05hbWUhPT0idW5kZWZpbmVkIj9iLmdldEVsZW1lbnRz
QnlUYWdOYW1lKCIqIik6W10pO3JldHVybntzZXQ6ZCxleHByOmF9fSxpLmZpbHRlcj1mdW5jdGlv
bihhLGMsZCxlKXt2YXIgZixnLGg9YSxrPVtdLGw9YyxtPWMmJmNbMF0mJmkuaXNYTUwoY1swXSk7
d2hpbGUoYSYmYy5sZW5ndGgpe2Zvcih2YXIgbiBpbiBqLmZpbHRlcilpZigoZj1qLmxlZnRNYXRj
aFtuXS5leGVjKGEpKSE9bnVsbCYmZlsyXSl7dmFyIG8scCxxPWouZmlsdGVyW25dLHI9ZlsxXTtn
PSExLGYuc3BsaWNlKDEsMSk7aWYoci5zdWJzdHIoci5sZW5ndGgtMSk9PT0iXFwiKWNvbnRpbnVl
O2w9PT1rJiYoaz1bXSk7aWYoai5wcmVGaWx0ZXJbbl0pe2Y9ai5wcmVGaWx0ZXJbbl0oZixsLGQs
ayxlLG0pO2lmKGYpe2lmKGY9PT0hMCljb250aW51ZX1lbHNlIGc9bz0hMH1pZihmKWZvcih2YXIg
cz0wOyhwPWxbc10pIT1udWxsO3MrKylpZihwKXtvPXEocCxmLHMsbCk7dmFyIHQ9ZV4hIW87ZCYm
byE9bnVsbD90P2c9ITA6bFtzXT0hMTp0JiYoay5wdXNoKHApLGc9ITApfWlmKG8hPT1iKXtkfHwo
bD1rKSxhPWEucmVwbGFjZShqLm1hdGNoW25dLCIiKTtpZighZylyZXR1cm5bXTticmVha319aWYo
YT09PWgpaWYoZz09bnVsbClpLmVycm9yKGEpO2Vsc2UgYnJlYWs7aD1hfXJldHVybiBsfSxpLmVy
cm9yPWZ1bmN0aW9uKGEpe3Rocm93IlN5bnRheCBlcnJvciwgdW5yZWNvZ25pemVkIGV4cHJlc3Np
b246ICIrYX07dmFyIGo9aS5zZWxlY3RvcnM9e29yZGVyOlsiSUQiLCJOQU1FIiwiVEFHIl0sbWF0
Y2g6e0lEOi8jKCg/Oltcd1x1MDBjMC1cdUZGRkZcLV18XFwuKSspLyxDTEFTUzovXC4oKD86W1x3
XHUwMGMwLVx1RkZGRlwtXXxcXC4pKykvLE5BTUU6L1xbbmFtZT1bJyJdKigoPzpbXHdcdTAwYzAt
XHVGRkZGXC1dfFxcLikrKVsnIl0qXF0vLEFUVFI6L1xbXHMqKCg/Oltcd1x1MDBjMC1cdUZGRkZc
LV18XFwuKSspXHMqKD86KFxTPz0pXHMqKD86KFsnIl0pKC4qPylcM3woIz8oPzpbXHdcdTAwYzAt
XHVGRkZGXC1dfFxcLikqKXwpfClccypcXS8sVEFHOi9eKCg/Oltcd1x1MDBjMC1cdUZGRkZcKlwt
XXxcXC4pKykvLENISUxEOi86KG9ubHl8bnRofGxhc3R8Zmlyc3QpLWNoaWxkKD86XChccyooZXZl
bnxvZGR8KD86WytcLV0/XGQrfCg/OlsrXC1dP1xkKik/blxzKig/OlsrXC1dXHMqXGQrKT8pKVxz
KlwpKT8vLFBPUzovOihudGh8ZXF8Z3R8bHR8Zmlyc3R8bGFzdHxldmVufG9kZCkoPzpcKChcZCop
XCkpPyg/PVteXC1dfCQpLyxQU0VVRE86LzooKD86W1x3XHUwMGMwLVx1RkZGRlwtXXxcXC4pKyko
PzpcKChbJyJdPykoKD86XChbXlwpXStcKXxbXlwoXCldKikrKVwyXCkpPy99LGxlZnRNYXRjaDp7
fSxhdHRyTWFwOnsiY2xhc3MiOiJjbGFzc05hbWUiLCJmb3IiOiJodG1sRm9yIn0sYXR0ckhhbmRs
ZTp7aHJlZjpmdW5jdGlvbihhKXtyZXR1cm4gYS5nZXRBdHRyaWJ1dGUoImhyZWYiKX19LHJlbGF0
aXZlOnsiKyI6ZnVuY3Rpb24oYSxiKXt2YXIgYz10eXBlb2YgYj09PSJzdHJpbmciLGQ9YyYmIS9c
Vy8udGVzdChiKSxlPWMmJiFkO2QmJihiPWIudG9Mb3dlckNhc2UoKSk7Zm9yKHZhciBmPTAsZz1h
Lmxlbmd0aCxoO2Y8ZztmKyspaWYoaD1hW2ZdKXt3aGlsZSgoaD1oLnByZXZpb3VzU2libGluZykm
Jmgubm9kZVR5cGUhPT0xKXt9YVtmXT1lfHxoJiZoLm5vZGVOYW1lLnRvTG93ZXJDYXNlKCk9PT1i
P2h8fCExOmg9PT1ifWUmJmkuZmlsdGVyKGIsYSwhMCl9LCI+IjpmdW5jdGlvbihhLGIpe3ZhciBj
LGQ9dHlwZW9mIGI9PT0ic3RyaW5nIixlPTAsZj1hLmxlbmd0aDtpZihkJiYhL1xXLy50ZXN0KGIp
KXtiPWIudG9Mb3dlckNhc2UoKTtmb3IoO2U8ZjtlKyspe2M9YVtlXTtpZihjKXt2YXIgZz1jLnBh
cmVudE5vZGU7YVtlXT1nLm5vZGVOYW1lLnRvTG93ZXJDYXNlKCk9PT1iP2c6ITF9fX1lbHNle2Zv
cig7ZTxmO2UrKyljPWFbZV0sYyYmKGFbZV09ZD9jLnBhcmVudE5vZGU6Yy5wYXJlbnROb2RlPT09
Yik7ZCYmaS5maWx0ZXIoYixhLCEwKX19LCIiOmZ1bmN0aW9uKGEsYixjKXt2YXIgZCxmPWUrKyxn
PXM7dHlwZW9mIGI9PT0ic3RyaW5nIiYmIS9cVy8udGVzdChiKSYmKGI9Yi50b0xvd2VyQ2FzZSgp
LGQ9YixnPXIpLGcoInBhcmVudE5vZGUiLGIsZixhLGQsYyl9LCJ+IjpmdW5jdGlvbihhLGIsYyl7
dmFyIGQsZj1lKyssZz1zO3R5cGVvZiBiPT09InN0cmluZyImJiEvXFcvLnRlc3QoYikmJihiPWIu
dG9Mb3dlckNhc2UoKSxkPWIsZz1yKSxnKCJwcmV2aW91c1NpYmxpbmciLGIsZixhLGQsYyl9fSxm
aW5kOntJRDpmdW5jdGlvbihhLGIsYyl7aWYodHlwZW9mIGIuZ2V0RWxlbWVudEJ5SWQhPT0idW5k
ZWZpbmVkIiYmIWMpe3ZhciBkPWIuZ2V0RWxlbWVudEJ5SWQoYVsxXSk7cmV0dXJuIGQmJmQucGFy
ZW50Tm9kZT9bZF06W119fSxOQU1FOmZ1bmN0aW9uKGEsYil7aWYodHlwZW9mIGIuZ2V0RWxlbWVu
dHNCeU5hbWUhPT0idW5kZWZpbmVkIil7dmFyIGM9W10sZD1iLmdldEVsZW1lbnRzQnlOYW1lKGFb
MV0pO2Zvcih2YXIgZT0wLGY9ZC5sZW5ndGg7ZTxmO2UrKylkW2VdLmdldEF0dHJpYnV0ZSgibmFt
ZSIpPT09YVsxXSYmYy5wdXNoKGRbZV0pO3JldHVybiBjLmxlbmd0aD09PTA/bnVsbDpjfX0sVEFH
OmZ1bmN0aW9uKGEsYil7aWYodHlwZW9mIGIuZ2V0RWxlbWVudHNCeVRhZ05hbWUhPT0idW5kZWZp
bmVkIilyZXR1cm4gYi5nZXRFbGVtZW50c0J5VGFnTmFtZShhWzFdKX19LHByZUZpbHRlcjp7Q0xB
U1M6ZnVuY3Rpb24oYSxiLGMsZCxlLGYpe2E9IiAiK2FbMV0ucmVwbGFjZSgvXFwvZywiIikrIiAi
O2lmKGYpcmV0dXJuIGE7Zm9yKHZhciBnPTAsaDsoaD1iW2ddKSE9bnVsbDtnKyspaCYmKGVeKGgu
Y2xhc3NOYW1lJiYoIiAiK2guY2xhc3NOYW1lKyIgIikucmVwbGFjZSgvW1x0XG5ccl0vZywiICIp
LmluZGV4T2YoYSk+PTApP2N8fGQucHVzaChoKTpjJiYoYltnXT0hMSkpO3JldHVybiExfSxJRDpm
dW5jdGlvbihhKXtyZXR1cm4gYVsxXS5yZXBsYWNlKC9cXC9nLCIiKX0sVEFHOmZ1bmN0aW9uKGEs
Yil7cmV0dXJuIGFbMV0udG9Mb3dlckNhc2UoKX0sQ0hJTEQ6ZnVuY3Rpb24oYSl7aWYoYVsxXT09
PSJudGgiKXthWzJdfHxpLmVycm9yKGFbMF0pLGFbMl09YVsyXS5yZXBsYWNlKC9eXCt8XHMqL2cs
IiIpO3ZhciBiPS8oLT8pKFxkKikoPzpuKFsrXC1dP1xkKikpPy8uZXhlYyhhWzJdPT09ImV2ZW4i
JiYiMm4ifHxhWzJdPT09Im9kZCImJiIybisxInx8IS9cRC8udGVzdChhWzJdKSYmIjBuKyIrYVsy
XXx8YVsyXSk7YVsyXT1iWzFdKyhiWzJdfHwxKS0wLGFbM109YlszXS0wfWVsc2UgYVsyXSYmaS5l
cnJvcihhWzBdKTthWzBdPWUrKztyZXR1cm4gYX0sQVRUUjpmdW5jdGlvbihhLGIsYyxkLGUsZil7
dmFyIGc9YVsxXT1hWzFdLnJlcGxhY2UoL1xcL2csIiIpOyFmJiZqLmF0dHJNYXBbZ10mJihhWzFd
PWouYXR0ck1hcFtnXSksYVs0XT0oYVs0XXx8YVs1XXx8IiIpLnJlcGxhY2UoL1xcL2csIiIpLGFb
Ml09PT0ifj0iJiYoYVs0XT0iICIrYVs0XSsiICIpO3JldHVybiBhfSxQU0VVRE86ZnVuY3Rpb24o
YixjLGQsZSxmKXtpZihiWzFdPT09Im5vdCIpaWYoKGEuZXhlYyhiWzNdKXx8IiIpLmxlbmd0aD4x
fHwvXlx3Ly50ZXN0KGJbM10pKWJbM109aShiWzNdLG51bGwsbnVsbCxjKTtlbHNle3ZhciBnPWku
ZmlsdGVyKGJbM10sYyxkLCEwXmYpO2R8fGUucHVzaC5hcHBseShlLGcpO3JldHVybiExfWVsc2Ug
aWYoai5tYXRjaC5QT1MudGVzdChiWzBdKXx8ai5tYXRjaC5DSElMRC50ZXN0KGJbMF0pKXJldHVy
biEwO3JldHVybiBifSxQT1M6ZnVuY3Rpb24oYSl7YS51bnNoaWZ0KCEwKTtyZXR1cm4gYX19LGZp
bHRlcnM6e2VuYWJsZWQ6ZnVuY3Rpb24oYSl7cmV0dXJuIGEuZGlzYWJsZWQ9PT0hMSYmYS50eXBl
IT09ImhpZGRlbiJ9LGRpc2FibGVkOmZ1bmN0aW9uKGEpe3JldHVybiBhLmRpc2FibGVkPT09ITB9
LGNoZWNrZWQ6ZnVuY3Rpb24oYSl7cmV0dXJuIGEuY2hlY2tlZD09PSEwfSxzZWxlY3RlZDpmdW5j
dGlvbihhKXthLnBhcmVudE5vZGUuc2VsZWN0ZWRJbmRleDtyZXR1cm4gYS5zZWxlY3RlZD09PSEw
fSxwYXJlbnQ6ZnVuY3Rpb24oYSl7cmV0dXJuISFhLmZpcnN0Q2hpbGR9LGVtcHR5OmZ1bmN0aW9u
KGEpe3JldHVybiFhLmZpcnN0Q2hpbGR9LGhhczpmdW5jdGlvbihhLGIsYyl7cmV0dXJuISFpKGNb
M10sYSkubGVuZ3RofSxoZWFkZXI6ZnVuY3Rpb24oYSl7cmV0dXJuL2hcZC9pLnRlc3QoYS5ub2Rl
TmFtZSl9LHRleHQ6ZnVuY3Rpb24oYSl7cmV0dXJuInRleHQiPT09YS50eXBlfSxyYWRpbzpmdW5j
dGlvbihhKXtyZXR1cm4icmFkaW8iPT09YS50eXBlfSxjaGVja2JveDpmdW5jdGlvbihhKXtyZXR1
cm4iY2hlY2tib3giPT09YS50eXBlfSxmaWxlOmZ1bmN0aW9uKGEpe3JldHVybiJmaWxlIj09PWEu
dHlwZX0scGFzc3dvcmQ6ZnVuY3Rpb24oYSl7cmV0dXJuInBhc3N3b3JkIj09PWEudHlwZX0sc3Vi
bWl0OmZ1bmN0aW9uKGEpe3JldHVybiJzdWJtaXQiPT09YS50eXBlfSxpbWFnZTpmdW5jdGlvbihh
KXtyZXR1cm4iaW1hZ2UiPT09YS50eXBlfSxyZXNldDpmdW5jdGlvbihhKXtyZXR1cm4icmVzZXQi
PT09YS50eXBlfSxidXR0b246ZnVuY3Rpb24oYSl7cmV0dXJuImJ1dHRvbiI9PT1hLnR5cGV8fGEu
bm9kZU5hbWUudG9Mb3dlckNhc2UoKT09PSJidXR0b24ifSxpbnB1dDpmdW5jdGlvbihhKXtyZXR1
cm4vaW5wdXR8c2VsZWN0fHRleHRhcmVhfGJ1dHRvbi9pLnRlc3QoYS5ub2RlTmFtZSl9fSxzZXRG
aWx0ZXJzOntmaXJzdDpmdW5jdGlvbihhLGIpe3JldHVybiBiPT09MH0sbGFzdDpmdW5jdGlvbihh
LGIsYyxkKXtyZXR1cm4gYj09PWQubGVuZ3RoLTF9LGV2ZW46ZnVuY3Rpb24oYSxiKXtyZXR1cm4g
YiUyPT09MH0sb2RkOmZ1bmN0aW9uKGEsYil7cmV0dXJuIGIlMj09PTF9LGx0OmZ1bmN0aW9uKGEs
YixjKXtyZXR1cm4gYjxjWzNdLTB9LGd0OmZ1bmN0aW9uKGEsYixjKXtyZXR1cm4gYj5jWzNdLTB9
LG50aDpmdW5jdGlvbihhLGIsYyl7cmV0dXJuIGNbM10tMD09PWJ9LGVxOmZ1bmN0aW9uKGEsYixj
KXtyZXR1cm4gY1szXS0wPT09Yn19LGZpbHRlcjp7UFNFVURPOmZ1bmN0aW9uKGEsYixjLGQpe3Zh
ciBlPWJbMV0sZj1qLmZpbHRlcnNbZV07aWYoZilyZXR1cm4gZihhLGMsYixkKTtpZihlPT09ImNv
bnRhaW5zIilyZXR1cm4oYS50ZXh0Q29udGVudHx8YS5pbm5lclRleHR8fGkuZ2V0VGV4dChbYV0p
fHwiIikuaW5kZXhPZihiWzNdKT49MDtpZihlPT09Im5vdCIpe3ZhciBnPWJbM107Zm9yKHZhciBo
PTAsaz1nLmxlbmd0aDtoPGs7aCsrKWlmKGdbaF09PT1hKXJldHVybiExO3JldHVybiEwfWkuZXJy
b3IoZSl9LENISUxEOmZ1bmN0aW9uKGEsYil7dmFyIGM9YlsxXSxkPWE7c3dpdGNoKGMpe2Nhc2Ui
b25seSI6Y2FzZSJmaXJzdCI6d2hpbGUoZD1kLnByZXZpb3VzU2libGluZylpZihkLm5vZGVUeXBl
PT09MSlyZXR1cm4hMTtpZihjPT09ImZpcnN0IilyZXR1cm4hMDtkPWE7Y2FzZSJsYXN0Ijp3aGls
ZShkPWQubmV4dFNpYmxpbmcpaWYoZC5ub2RlVHlwZT09PTEpcmV0dXJuITE7cmV0dXJuITA7Y2Fz
ZSJudGgiOnZhciBlPWJbMl0sZj1iWzNdO2lmKGU9PT0xJiZmPT09MClyZXR1cm4hMDt2YXIgZz1i
WzBdLGg9YS5wYXJlbnROb2RlO2lmKGgmJihoLnNpemNhY2hlIT09Z3x8IWEubm9kZUluZGV4KSl7
dmFyIGk9MDtmb3IoZD1oLmZpcnN0Q2hpbGQ7ZDtkPWQubmV4dFNpYmxpbmcpZC5ub2RlVHlwZT09
PTEmJihkLm5vZGVJbmRleD0rK2kpO2guc2l6Y2FjaGU9Z312YXIgaj1hLm5vZGVJbmRleC1mO3Jl
dHVybiBlPT09MD9qPT09MDpqJWU9PT0wJiZqL2U+PTB9fSxJRDpmdW5jdGlvbihhLGIpe3JldHVy
biBhLm5vZGVUeXBlPT09MSYmYS5nZXRBdHRyaWJ1dGUoImlkIik9PT1ifSxUQUc6ZnVuY3Rpb24o
YSxiKXtyZXR1cm4gYj09PSIqIiYmYS5ub2RlVHlwZT09PTF8fGEubm9kZU5hbWUudG9Mb3dlckNh
c2UoKT09PWJ9LENMQVNTOmZ1bmN0aW9uKGEsYil7cmV0dXJuKCIgIisoYS5jbGFzc05hbWV8fGEu
Z2V0QXR0cmlidXRlKCJjbGFzcyIpKSsiICIpLmluZGV4T2YoYik+LTF9LEFUVFI6ZnVuY3Rpb24o
YSxiKXt2YXIgYz1iWzFdLGQ9ai5hdHRySGFuZGxlW2NdP2ouYXR0ckhhbmRsZVtjXShhKTphW2Nd
IT1udWxsP2FbY106YS5nZXRBdHRyaWJ1dGUoYyksZT1kKyIiLGY9YlsyXSxnPWJbNF07cmV0dXJu
IGQ9PW51bGw/Zj09PSIhPSI6Zj09PSI9Ij9lPT09ZzpmPT09Iio9Ij9lLmluZGV4T2YoZyk+PTA6
Zj09PSJ+PSI/KCIgIitlKyIgIikuaW5kZXhPZihnKT49MDpnP2Y9PT0iIT0iP2UhPT1nOmY9PT0i
Xj0iP2UuaW5kZXhPZihnKT09PTA6Zj09PSIkPSI/ZS5zdWJzdHIoZS5sZW5ndGgtZy5sZW5ndGgp
PT09ZzpmPT09Inw9Ij9lPT09Z3x8ZS5zdWJzdHIoMCxnLmxlbmd0aCsxKT09PWcrIi0iOiExOmUm
JmQhPT0hMX0sUE9TOmZ1bmN0aW9uKGEsYixjLGQpe3ZhciBlPWJbMl0sZj1qLnNldEZpbHRlcnNb
ZV07aWYoZilyZXR1cm4gZihhLGMsYixkKX19fSxrPWoubWF0Y2guUE9TLGw9ZnVuY3Rpb24oYSxi
KXtyZXR1cm4iXFwiKyhiLTArMSl9O2Zvcih2YXIgbSBpbiBqLm1hdGNoKWoubWF0Y2hbbV09bmV3
IFJlZ0V4cChqLm1hdGNoW21dLnNvdXJjZSsvKD8hW15cW10qXF0pKD8hW15cKF0qXCkpLy5zb3Vy
Y2UpLGoubGVmdE1hdGNoW21dPW5ldyBSZWdFeHAoLyheKD86LnxccnxcbikqPykvLnNvdXJjZStq
Lm1hdGNoW21dLnNvdXJjZS5yZXBsYWNlKC9cXChcZCspL2csbCkpO3ZhciBuPWZ1bmN0aW9uKGEs
Yil7YT1BcnJheS5wcm90b3R5cGUuc2xpY2UuY2FsbChhLDApO2lmKGIpe2IucHVzaC5hcHBseShi
LGEpO3JldHVybiBifXJldHVybiBhfTt0cnl7QXJyYXkucHJvdG90eXBlLnNsaWNlLmNhbGwoYy5k
b2N1bWVudEVsZW1lbnQuY2hpbGROb2RlcywwKVswXS5ub2RlVHlwZX1jYXRjaChvKXtuPWZ1bmN0
aW9uKGEsYil7dmFyIGM9MCxkPWJ8fFtdO2lmKGYuY2FsbChhKT09PSJbb2JqZWN0IEFycmF5XSIp
QXJyYXkucHJvdG90eXBlLnB1c2guYXBwbHkoZCxhKTtlbHNlIGlmKHR5cGVvZiBhLmxlbmd0aD09
PSJudW1iZXIiKWZvcih2YXIgZT1hLmxlbmd0aDtjPGU7YysrKWQucHVzaChhW2NdKTtlbHNlIGZv
cig7YVtjXTtjKyspZC5wdXNoKGFbY10pO3JldHVybiBkfX12YXIgcCxxO2MuZG9jdW1lbnRFbGVt
ZW50LmNvbXBhcmVEb2N1bWVudFBvc2l0aW9uP3A9ZnVuY3Rpb24oYSxiKXtpZihhPT09Yil7Zz0h
MDtyZXR1cm4gMH1pZighYS5jb21wYXJlRG9jdW1lbnRQb3NpdGlvbnx8IWIuY29tcGFyZURvY3Vt
ZW50UG9zaXRpb24pcmV0dXJuIGEuY29tcGFyZURvY3VtZW50UG9zaXRpb24/LTE6MTtyZXR1cm4g
YS5jb21wYXJlRG9jdW1lbnRQb3NpdGlvbihiKSY0Py0xOjF9OihwPWZ1bmN0aW9uKGEsYil7dmFy
IGMsZCxlPVtdLGY9W10saD1hLnBhcmVudE5vZGUsaT1iLnBhcmVudE5vZGUsaj1oO2lmKGE9PT1i
KXtnPSEwO3JldHVybiAwfWlmKGg9PT1pKXJldHVybiBxKGEsYik7aWYoIWgpcmV0dXJuLTE7aWYo
IWkpcmV0dXJuIDE7d2hpbGUoaillLnVuc2hpZnQoaiksaj1qLnBhcmVudE5vZGU7aj1pO3doaWxl
KGopZi51bnNoaWZ0KGopLGo9ai5wYXJlbnROb2RlO2M9ZS5sZW5ndGgsZD1mLmxlbmd0aDtmb3Io
dmFyIGs9MDtrPGMmJms8ZDtrKyspaWYoZVtrXSE9PWZba10pcmV0dXJuIHEoZVtrXSxmW2tdKTty
ZXR1cm4gaz09PWM/cShhLGZba10sLTEpOnEoZVtrXSxiLDEpfSxxPWZ1bmN0aW9uKGEsYixjKXtp
ZihhPT09YilyZXR1cm4gYzt2YXIgZD1hLm5leHRTaWJsaW5nO3doaWxlKGQpe2lmKGQ9PT1iKXJl
dHVybi0xO2Q9ZC5uZXh0U2libGluZ31yZXR1cm4gMX0pLGkuZ2V0VGV4dD1mdW5jdGlvbihhKXt2
YXIgYj0iIixjO2Zvcih2YXIgZD0wO2FbZF07ZCsrKWM9YVtkXSxjLm5vZGVUeXBlPT09M3x8Yy5u
b2RlVHlwZT09PTQ/Yis9Yy5ub2RlVmFsdWU6Yy5ub2RlVHlwZSE9PTgmJihiKz1pLmdldFRleHQo
Yy5jaGlsZE5vZGVzKSk7cmV0dXJuIGJ9LGZ1bmN0aW9uKCl7dmFyIGE9Yy5jcmVhdGVFbGVtZW50
KCJkaXYiKSxkPSJzY3JpcHQiKyhuZXcgRGF0ZSkuZ2V0VGltZSgpLGU9Yy5kb2N1bWVudEVsZW1l
bnQ7YS5pbm5lckhUTUw9IjxhIG5hbWU9JyIrZCsiJy8+IixlLmluc2VydEJlZm9yZShhLGUuZmly
c3RDaGlsZCksYy5nZXRFbGVtZW50QnlJZChkKSYmKGouZmluZC5JRD1mdW5jdGlvbihhLGMsZCl7
aWYodHlwZW9mIGMuZ2V0RWxlbWVudEJ5SWQhPT0idW5kZWZpbmVkIiYmIWQpe3ZhciBlPWMuZ2V0
RWxlbWVudEJ5SWQoYVsxXSk7cmV0dXJuIGU/ZS5pZD09PWFbMV18fHR5cGVvZiBlLmdldEF0dHJp
YnV0ZU5vZGUhPT0idW5kZWZpbmVkIiYmZS5nZXRBdHRyaWJ1dGVOb2RlKCJpZCIpLm5vZGVWYWx1
ZT09PWFbMV0/W2VdOmI6W119fSxqLmZpbHRlci5JRD1mdW5jdGlvbihhLGIpe3ZhciBjPXR5cGVv
ZiBhLmdldEF0dHJpYnV0ZU5vZGUhPT0idW5kZWZpbmVkIiYmYS5nZXRBdHRyaWJ1dGVOb2RlKCJp
ZCIpO3JldHVybiBhLm5vZGVUeXBlPT09MSYmYyYmYy5ub2RlVmFsdWU9PT1ifSksZS5yZW1vdmVD
aGlsZChhKSxlPWE9bnVsbH0oKSxmdW5jdGlvbigpe3ZhciBhPWMuY3JlYXRlRWxlbWVudCgiZGl2
Iik7YS5hcHBlbmRDaGlsZChjLmNyZWF0ZUNvbW1lbnQoIiIpKSxhLmdldEVsZW1lbnRzQnlUYWdO
YW1lKCIqIikubGVuZ3RoPjAmJihqLmZpbmQuVEFHPWZ1bmN0aW9uKGEsYil7dmFyIGM9Yi5nZXRF
bGVtZW50c0J5VGFnTmFtZShhWzFdKTtpZihhWzFdPT09IioiKXt2YXIgZD1bXTtmb3IodmFyIGU9
MDtjW2VdO2UrKyljW2VdLm5vZGVUeXBlPT09MSYmZC5wdXNoKGNbZV0pO2M9ZH1yZXR1cm4gY30p
LGEuaW5uZXJIVE1MPSI8YSBocmVmPScjJz48L2E+IixhLmZpcnN0Q2hpbGQmJnR5cGVvZiBhLmZp
cnN0Q2hpbGQuZ2V0QXR0cmlidXRlIT09InVuZGVmaW5lZCImJmEuZmlyc3RDaGlsZC5nZXRBdHRy
aWJ1dGUoImhyZWYiKSE9PSIjIiYmKGouYXR0ckhhbmRsZS5ocmVmPWZ1bmN0aW9uKGEpe3JldHVy
biBhLmdldEF0dHJpYnV0ZSgiaHJlZiIsMil9KSxhPW51bGx9KCksYy5xdWVyeVNlbGVjdG9yQWxs
JiZmdW5jdGlvbigpe3ZhciBhPWksYj1jLmNyZWF0ZUVsZW1lbnQoImRpdiIpLGQ9Il9fc2l6emxl
X18iO2IuaW5uZXJIVE1MPSI8cCBjbGFzcz0nVEVTVCc+PC9wPiI7aWYoIWIucXVlcnlTZWxlY3Rv
ckFsbHx8Yi5xdWVyeVNlbGVjdG9yQWxsKCIuVEVTVCIpLmxlbmd0aCE9PTApe2k9ZnVuY3Rpb24o
YixlLGYsZyl7ZT1lfHxjO2lmKCFnJiYhaS5pc1hNTChlKSl7dmFyIGg9L14oXHcrJCl8XlwuKFtc
d1wtXSskKXxeIyhbXHdcLV0rJCkvLmV4ZWMoYik7aWYoaCYmKGUubm9kZVR5cGU9PT0xfHxlLm5v
ZGVUeXBlPT09OSkpe2lmKGhbMV0pcmV0dXJuIG4oZS5nZXRFbGVtZW50c0J5VGFnTmFtZShiKSxm
KTtpZihoWzJdJiZqLmZpbmQuQ0xBU1MmJmUuZ2V0RWxlbWVudHNCeUNsYXNzTmFtZSlyZXR1cm4g
bihlLmdldEVsZW1lbnRzQnlDbGFzc05hbWUoaFsyXSksZil9aWYoZS5ub2RlVHlwZT09PTkpe2lm
KGI9PT0iYm9keSImJmUuYm9keSlyZXR1cm4gbihbZS5ib2R5XSxmKTtpZihoJiZoWzNdKXt2YXIg
az1lLmdldEVsZW1lbnRCeUlkKGhbM10pO2lmKCFrfHwhay5wYXJlbnROb2RlKXJldHVybiBuKFtd
LGYpO2lmKGsuaWQ9PT1oWzNdKXJldHVybiBuKFtrXSxmKX10cnl7cmV0dXJuIG4oZS5xdWVyeVNl
bGVjdG9yQWxsKGIpLGYpfWNhdGNoKGwpe319ZWxzZSBpZihlLm5vZGVUeXBlPT09MSYmZS5ub2Rl
TmFtZS50b0xvd2VyQ2FzZSgpIT09Im9iamVjdCIpe3ZhciBtPWUuZ2V0QXR0cmlidXRlKCJpZCIp
LG89bXx8ZCxwPWUucGFyZW50Tm9kZSxxPS9eXHMqWyt+XS8udGVzdChiKTttP289by5yZXBsYWNl
KC8nL2csIlxcJCYiKTplLnNldEF0dHJpYnV0ZSgiaWQiLG8pLHEmJnAmJihlPWUucGFyZW50Tm9k
ZSk7dHJ5e2lmKCFxfHxwKXJldHVybiBuKGUucXVlcnlTZWxlY3RvckFsbCgiW2lkPSciK28rIidd
ICIrYiksZil9Y2F0Y2gocil7fWZpbmFsbHl7bXx8ZS5yZW1vdmVBdHRyaWJ1dGUoImlkIil9fX1y
ZXR1cm4gYShiLGUsZixnKX07Zm9yKHZhciBlIGluIGEpaVtlXT1hW2VdO2I9bnVsbH19KCksZnVu
Y3Rpb24oKXt2YXIgYT1jLmRvY3VtZW50RWxlbWVudCxiPWEubWF0Y2hlc1NlbGVjdG9yfHxhLm1v
ek1hdGNoZXNTZWxlY3Rvcnx8YS53ZWJraXRNYXRjaGVzU2VsZWN0b3J8fGEubXNNYXRjaGVzU2Vs
ZWN0b3IsZD0hMTt0cnl7Yi5jYWxsKGMuZG9jdW1lbnRFbGVtZW50LCJbdGVzdCE9JyddOnNpenps
ZSIpfWNhdGNoKGUpe2Q9ITB9YiYmKGkubWF0Y2hlc1NlbGVjdG9yPWZ1bmN0aW9uKGEsYyl7Yz1j
LnJlcGxhY2UoL1w9XHMqKFteJyJcXV0qKVxzKlxdL2csIj0nJDEnXSIpO2lmKCFpLmlzWE1MKGEp
KXRyeXtpZihkfHwhai5tYXRjaC5QU0VVRE8udGVzdChjKSYmIS8hPS8udGVzdChjKSlyZXR1cm4g
Yi5jYWxsKGEsYyl9Y2F0Y2goZSl7fXJldHVybiBpKGMsbnVsbCxudWxsLFthXSkubGVuZ3RoPjB9
KX0oKSxmdW5jdGlvbigpe3ZhciBhPWMuY3JlYXRlRWxlbWVudCgiZGl2Iik7YS5pbm5lckhUTUw9
IjxkaXYgY2xhc3M9J3Rlc3QgZSc+PC9kaXY+PGRpdiBjbGFzcz0ndGVzdCc+PC9kaXY+IjtpZihh
LmdldEVsZW1lbnRzQnlDbGFzc05hbWUmJmEuZ2V0RWxlbWVudHNCeUNsYXNzTmFtZSgiZSIpLmxl
bmd0aCE9PTApe2EubGFzdENoaWxkLmNsYXNzTmFtZT0iZSI7aWYoYS5nZXRFbGVtZW50c0J5Q2xh
c3NOYW1lKCJlIikubGVuZ3RoPT09MSlyZXR1cm47ai5vcmRlci5zcGxpY2UoMSwwLCJDTEFTUyIp
LGouZmluZC5DTEFTUz1mdW5jdGlvbihhLGIsYyl7aWYodHlwZW9mIGIuZ2V0RWxlbWVudHNCeUNs
YXNzTmFtZSE9PSJ1bmRlZmluZWQiJiYhYylyZXR1cm4gYi5nZXRFbGVtZW50c0J5Q2xhc3NOYW1l
KGFbMV0pfSxhPW51bGx9fSgpLGMuZG9jdW1lbnRFbGVtZW50LmNvbnRhaW5zP2kuY29udGFpbnM9
ZnVuY3Rpb24oYSxiKXtyZXR1cm4gYSE9PWImJihhLmNvbnRhaW5zP2EuY29udGFpbnMoYik6ITAp
fTpjLmRvY3VtZW50RWxlbWVudC5jb21wYXJlRG9jdW1lbnRQb3NpdGlvbj9pLmNvbnRhaW5zPWZ1
bmN0aW9uKGEsYil7cmV0dXJuISEoYS5jb21wYXJlRG9jdW1lbnRQb3NpdGlvbihiKSYxNil9Omku
Y29udGFpbnM9ZnVuY3Rpb24oKXtyZXR1cm4hMX0saS5pc1hNTD1mdW5jdGlvbihhKXt2YXIgYj0o
YT9hLm93bmVyRG9jdW1lbnR8fGE6MCkuZG9jdW1lbnRFbGVtZW50O3JldHVybiBiP2Iubm9kZU5h
bWUhPT0iSFRNTCI6ITF9O3ZhciB0PWZ1bmN0aW9uKGEsYil7dmFyIGMsZD1bXSxlPSIiLGY9Yi5u
b2RlVHlwZT9bYl06Yjt3aGlsZShjPWoubWF0Y2guUFNFVURPLmV4ZWMoYSkpZSs9Y1swXSxhPWEu
cmVwbGFjZShqLm1hdGNoLlBTRVVETywiIik7YT1qLnJlbGF0aXZlW2FdP2ErIioiOmE7Zm9yKHZh
ciBnPTAsaD1mLmxlbmd0aDtnPGg7ZysrKWkoYSxmW2ddLGQpO3JldHVybiBpLmZpbHRlcihlLGQp
fTtkLmZpbmQ9aSxkLmV4cHI9aS5zZWxlY3RvcnMsZC5leHByWyI6Il09ZC5leHByLmZpbHRlcnMs
ZC51bmlxdWU9aS51bmlxdWVTb3J0LGQudGV4dD1pLmdldFRleHQsZC5pc1hNTERvYz1pLmlzWE1M
LGQuY29udGFpbnM9aS5jb250YWluc30oKTt2YXIgRz0vVW50aWwkLyxIPS9eKD86cGFyZW50c3xw
cmV2VW50aWx8cHJldkFsbCkvLEk9LywvLEo9L14uW146I1xbXC4sXSokLyxLPUFycmF5LnByb3Rv
dHlwZS5zbGljZSxMPWQuZXhwci5tYXRjaC5QT1MsTT17Y2hpbGRyZW46ITAsY29udGVudHM6ITAs
bmV4dDohMCxwcmV2OiEwfTtkLmZuLmV4dGVuZCh7ZmluZDpmdW5jdGlvbihhKXt2YXIgYj10aGlz
LnB1c2hTdGFjaygiIiwiZmluZCIsYSksYz0wO2Zvcih2YXIgZT0wLGY9dGhpcy5sZW5ndGg7ZTxm
O2UrKyl7Yz1iLmxlbmd0aCxkLmZpbmQoYSx0aGlzW2VdLGIpO2lmKGU+MClmb3IodmFyIGc9Yztn
PGIubGVuZ3RoO2crKylmb3IodmFyIGg9MDtoPGM7aCsrKWlmKGJbaF09PT1iW2ddKXtiLnNwbGlj
ZShnLS0sMSk7YnJlYWt9fXJldHVybiBifSxoYXM6ZnVuY3Rpb24oYSl7dmFyIGI9ZChhKTtyZXR1
cm4gdGhpcy5maWx0ZXIoZnVuY3Rpb24oKXtmb3IodmFyIGE9MCxjPWIubGVuZ3RoO2E8YzthKysp
aWYoZC5jb250YWlucyh0aGlzLGJbYV0pKXJldHVybiEwfSl9LG5vdDpmdW5jdGlvbihhKXtyZXR1
cm4gdGhpcy5wdXNoU3RhY2soTyh0aGlzLGEsITEpLCJub3QiLGEpfSxmaWx0ZXI6ZnVuY3Rpb24o
YSl7cmV0dXJuIHRoaXMucHVzaFN0YWNrKE8odGhpcyxhLCEwKSwiZmlsdGVyIixhKX0saXM6ZnVu
Y3Rpb24oYSl7cmV0dXJuISFhJiZkLmZpbHRlcihhLHRoaXMpLmxlbmd0aD4wfSxjbG9zZXN0OmZ1
bmN0aW9uKGEsYil7dmFyIGM9W10sZSxmLGc9dGhpc1swXTtpZihkLmlzQXJyYXkoYSkpe3ZhciBo
LGksaj17fSxrPTE7aWYoZyYmYS5sZW5ndGgpe2ZvcihlPTAsZj1hLmxlbmd0aDtlPGY7ZSsrKWk9
YVtlXSxqW2ldfHwoaltpXT1kLmV4cHIubWF0Y2guUE9TLnRlc3QoaSk/ZChpLGJ8fHRoaXMuY29u
dGV4dCk6aSk7d2hpbGUoZyYmZy5vd25lckRvY3VtZW50JiZnIT09Yil7Zm9yKGkgaW4gailoPWpb
aV0sKGguanF1ZXJ5P2guaW5kZXgoZyk+LTE6ZChnKS5pcyhoKSkmJmMucHVzaCh7c2VsZWN0b3I6
aSxlbGVtOmcsbGV2ZWw6a30pO2c9Zy5wYXJlbnROb2RlLGsrK319cmV0dXJuIGN9dmFyIGw9TC50
ZXN0KGEpP2QoYSxifHx0aGlzLmNvbnRleHQpOm51bGw7Zm9yKGU9MCxmPXRoaXMubGVuZ3RoO2U8
ZjtlKyspe2c9dGhpc1tlXTt3aGlsZShnKXtpZihsP2wuaW5kZXgoZyk+LTE6ZC5maW5kLm1hdGNo
ZXNTZWxlY3RvcihnLGEpKXtjLnB1c2goZyk7YnJlYWt9Zz1nLnBhcmVudE5vZGU7aWYoIWd8fCFn
Lm93bmVyRG9jdW1lbnR8fGc9PT1iKWJyZWFrfX1jPWMubGVuZ3RoPjE/ZC51bmlxdWUoYyk6Yzty
ZXR1cm4gdGhpcy5wdXNoU3RhY2soYywiY2xvc2VzdCIsYSl9LGluZGV4OmZ1bmN0aW9uKGEpe2lm
KCFhfHx0eXBlb2YgYT09PSJzdHJpbmciKXJldHVybiBkLmluQXJyYXkodGhpc1swXSxhP2QoYSk6
dGhpcy5wYXJlbnQoKS5jaGlsZHJlbigpKTtyZXR1cm4gZC5pbkFycmF5KGEuanF1ZXJ5P2FbMF06
YSx0aGlzKX0sYWRkOmZ1bmN0aW9uKGEsYil7dmFyIGM9dHlwZW9mIGE9PT0ic3RyaW5nIj9kKGEs
Yik6ZC5tYWtlQXJyYXkoYSksZT1kLm1lcmdlKHRoaXMuZ2V0KCksYyk7cmV0dXJuIHRoaXMucHVz
aFN0YWNrKE4oY1swXSl8fE4oZVswXSk/ZTpkLnVuaXF1ZShlKSl9LGFuZFNlbGY6ZnVuY3Rpb24o
KXtyZXR1cm4gdGhpcy5hZGQodGhpcy5wcmV2T2JqZWN0KX19KSxkLmVhY2goe3BhcmVudDpmdW5j
dGlvbihhKXt2YXIgYj1hLnBhcmVudE5vZGU7cmV0dXJuIGImJmIubm9kZVR5cGUhPT0xMT9iOm51
bGx9LHBhcmVudHM6ZnVuY3Rpb24oYSl7cmV0dXJuIGQuZGlyKGEsInBhcmVudE5vZGUiKX0scGFy
ZW50c1VudGlsOmZ1bmN0aW9uKGEsYixjKXtyZXR1cm4gZC5kaXIoYSwicGFyZW50Tm9kZSIsYyl9
LG5leHQ6ZnVuY3Rpb24oYSl7cmV0dXJuIGQubnRoKGEsMiwibmV4dFNpYmxpbmciKX0scHJldjpm
dW5jdGlvbihhKXtyZXR1cm4gZC5udGgoYSwyLCJwcmV2aW91c1NpYmxpbmciKX0sbmV4dEFsbDpm
dW5jdGlvbihhKXtyZXR1cm4gZC5kaXIoYSwibmV4dFNpYmxpbmciKX0scHJldkFsbDpmdW5jdGlv
bihhKXtyZXR1cm4gZC5kaXIoYSwicHJldmlvdXNTaWJsaW5nIil9LG5leHRVbnRpbDpmdW5jdGlv
bihhLGIsYyl7cmV0dXJuIGQuZGlyKGEsIm5leHRTaWJsaW5nIixjKX0scHJldlVudGlsOmZ1bmN0
aW9uKGEsYixjKXtyZXR1cm4gZC5kaXIoYSwicHJldmlvdXNTaWJsaW5nIixjKX0sc2libGluZ3M6
ZnVuY3Rpb24oYSl7cmV0dXJuIGQuc2libGluZyhhLnBhcmVudE5vZGUuZmlyc3RDaGlsZCxhKX0s
Y2hpbGRyZW46ZnVuY3Rpb24oYSl7cmV0dXJuIGQuc2libGluZyhhLmZpcnN0Q2hpbGQpfSxjb250
ZW50czpmdW5jdGlvbihhKXtyZXR1cm4gZC5ub2RlTmFtZShhLCJpZnJhbWUiKT9hLmNvbnRlbnRE
b2N1bWVudHx8YS5jb250ZW50V2luZG93LmRvY3VtZW50OmQubWFrZUFycmF5KGEuY2hpbGROb2Rl
cyl9fSxmdW5jdGlvbihhLGIpe2QuZm5bYV09ZnVuY3Rpb24oYyxlKXt2YXIgZj1kLm1hcCh0aGlz
LGIsYyksZz1LLmNhbGwoYXJndW1lbnRzKTtHLnRlc3QoYSl8fChlPWMpLGUmJnR5cGVvZiBlPT09
InN0cmluZyImJihmPWQuZmlsdGVyKGUsZikpLGY9dGhpcy5sZW5ndGg+MSYmIU1bYV0/ZC51bmlx
dWUoZik6ZiwodGhpcy5sZW5ndGg+MXx8SS50ZXN0KGUpKSYmSC50ZXN0KGEpJiYoZj1mLnJldmVy
c2UoKSk7cmV0dXJuIHRoaXMucHVzaFN0YWNrKGYsYSxnLmpvaW4oIiwiKSl9fSksZC5leHRlbmQo
e2ZpbHRlcjpmdW5jdGlvbihhLGIsYyl7YyYmKGE9Ijpub3QoIithKyIpIik7cmV0dXJuIGIubGVu
Z3RoPT09MT9kLmZpbmQubWF0Y2hlc1NlbGVjdG9yKGJbMF0sYSk/W2JbMF1dOltdOmQuZmluZC5t
YXRjaGVzKGEsYil9LGRpcjpmdW5jdGlvbihhLGMsZSl7dmFyIGY9W10sZz1hW2NdO3doaWxlKGcm
Jmcubm9kZVR5cGUhPT05JiYoZT09PWJ8fGcubm9kZVR5cGUhPT0xfHwhZChnKS5pcyhlKSkpZy5u
b2RlVHlwZT09PTEmJmYucHVzaChnKSxnPWdbY107cmV0dXJuIGZ9LG50aDpmdW5jdGlvbihhLGIs
YyxkKXtiPWJ8fDE7dmFyIGU9MDtmb3IoO2E7YT1hW2NdKWlmKGEubm9kZVR5cGU9PT0xJiYrK2U9
PT1iKWJyZWFrO3JldHVybiBhfSxzaWJsaW5nOmZ1bmN0aW9uKGEsYil7dmFyIGM9W107Zm9yKDth
O2E9YS5uZXh0U2libGluZylhLm5vZGVUeXBlPT09MSYmYSE9PWImJmMucHVzaChhKTtyZXR1cm4g
Y319KTt2YXIgUD0vIGpRdWVyeVxkKz0iKD86XGQrfG51bGwpIi9nLFE9L15ccysvLFI9LzwoPyFh
cmVhfGJyfGNvbHxlbWJlZHxocnxpbWd8aW5wdXR8bGlua3xtZXRhfHBhcmFtKSgoW1x3Ol0rKVte
Pl0qKVwvPi9pZyxTPS88KFtcdzpdKykvLFQ9Lzx0Ym9keS9pLFU9Lzx8JiM/XHcrOy8sVj0vPCg/
OnNjcmlwdHxvYmplY3R8ZW1iZWR8b3B0aW9ufHN0eWxlKS9pLFc9L2NoZWNrZWRccyooPzpbXj1d
fD1ccyouY2hlY2tlZC4pL2ksWD17b3B0aW9uOlsxLCI8c2VsZWN0IG11bHRpcGxlPSdtdWx0aXBs
ZSc+IiwiPC9zZWxlY3Q+Il0sbGVnZW5kOlsxLCI8ZmllbGRzZXQ+IiwiPC9maWVsZHNldD4iXSx0
aGVhZDpbMSwiPHRhYmxlPiIsIjwvdGFibGU+Il0sdHI6WzIsIjx0YWJsZT48dGJvZHk+IiwiPC90
Ym9keT48L3RhYmxlPiJdLHRkOlszLCI8dGFibGU+PHRib2R5Pjx0cj4iLCI8L3RyPjwvdGJvZHk+
PC90YWJsZT4iXSxjb2w6WzIsIjx0YWJsZT48dGJvZHk+PC90Ym9keT48Y29sZ3JvdXA+IiwiPC9j
b2xncm91cD48L3RhYmxlPiJdLGFyZWE6WzEsIjxtYXA+IiwiPC9tYXA+Il0sX2RlZmF1bHQ6WzAs
IiIsIiJdfTtYLm9wdGdyb3VwPVgub3B0aW9uLFgudGJvZHk9WC50Zm9vdD1YLmNvbGdyb3VwPVgu
Y2FwdGlvbj1YLnRoZWFkLFgudGg9WC50ZCxkLnN1cHBvcnQuaHRtbFNlcmlhbGl6ZXx8KFguX2Rl
ZmF1bHQ9WzEsImRpdjxkaXY+IiwiPC9kaXY+Il0pLGQuZm4uZXh0ZW5kKHt0ZXh0OmZ1bmN0aW9u
KGEpe2lmKGQuaXNGdW5jdGlvbihhKSlyZXR1cm4gdGhpcy5lYWNoKGZ1bmN0aW9uKGIpe3ZhciBj
PWQodGhpcyk7Yy50ZXh0KGEuY2FsbCh0aGlzLGIsYy50ZXh0KCkpKX0pO2lmKHR5cGVvZiBhIT09
Im9iamVjdCImJmEhPT1iKXJldHVybiB0aGlzLmVtcHR5KCkuYXBwZW5kKCh0aGlzWzBdJiZ0aGlz
WzBdLm93bmVyRG9jdW1lbnR8fGMpLmNyZWF0ZVRleHROb2RlKGEpKTtyZXR1cm4gZC50ZXh0KHRo
aXMpfSx3cmFwQWxsOmZ1bmN0aW9uKGEpe2lmKGQuaXNGdW5jdGlvbihhKSlyZXR1cm4gdGhpcy5l
YWNoKGZ1bmN0aW9uKGIpe2QodGhpcykud3JhcEFsbChhLmNhbGwodGhpcyxiKSl9KTtpZih0aGlz
WzBdKXt2YXIgYj1kKGEsdGhpc1swXS5vd25lckRvY3VtZW50KS5lcSgwKS5jbG9uZSghMCk7dGhp
c1swXS5wYXJlbnROb2RlJiZiLmluc2VydEJlZm9yZSh0aGlzWzBdKSxiLm1hcChmdW5jdGlvbigp
e3ZhciBhPXRoaXM7d2hpbGUoYS5maXJzdENoaWxkJiZhLmZpcnN0Q2hpbGQubm9kZVR5cGU9PT0x
KWE9YS5maXJzdENoaWxkO3JldHVybiBhfSkuYXBwZW5kKHRoaXMpfXJldHVybiB0aGlzfSx3cmFw
SW5uZXI6ZnVuY3Rpb24oYSl7aWYoZC5pc0Z1bmN0aW9uKGEpKXJldHVybiB0aGlzLmVhY2goZnVu
Y3Rpb24oYil7ZCh0aGlzKS53cmFwSW5uZXIoYS5jYWxsKHRoaXMsYikpfSk7cmV0dXJuIHRoaXMu
ZWFjaChmdW5jdGlvbigpe3ZhciBiPWQodGhpcyksYz1iLmNvbnRlbnRzKCk7Yy5sZW5ndGg/Yy53
cmFwQWxsKGEpOmIuYXBwZW5kKGEpfSl9LHdyYXA6ZnVuY3Rpb24oYSl7cmV0dXJuIHRoaXMuZWFj
aChmdW5jdGlvbigpe2QodGhpcykud3JhcEFsbChhKX0pfSx1bndyYXA6ZnVuY3Rpb24oKXtyZXR1
cm4gdGhpcy5wYXJlbnQoKS5lYWNoKGZ1bmN0aW9uKCl7ZC5ub2RlTmFtZSh0aGlzLCJib2R5Iil8
fGQodGhpcykucmVwbGFjZVdpdGgodGhpcy5jaGlsZE5vZGVzKX0pLmVuZCgpfSxhcHBlbmQ6ZnVu
Y3Rpb24oKXtyZXR1cm4gdGhpcy5kb21NYW5pcChhcmd1bWVudHMsITAsZnVuY3Rpb24oYSl7dGhp
cy5ub2RlVHlwZT09PTEmJnRoaXMuYXBwZW5kQ2hpbGQoYSl9KX0scHJlcGVuZDpmdW5jdGlvbigp
e3JldHVybiB0aGlzLmRvbU1hbmlwKGFyZ3VtZW50cywhMCxmdW5jdGlvbihhKXt0aGlzLm5vZGVU
eXBlPT09MSYmdGhpcy5pbnNlcnRCZWZvcmUoYSx0aGlzLmZpcnN0Q2hpbGQpfSl9LGJlZm9yZTpm
dW5jdGlvbigpe2lmKHRoaXNbMF0mJnRoaXNbMF0ucGFyZW50Tm9kZSlyZXR1cm4gdGhpcy5kb21N
YW5pcChhcmd1bWVudHMsITEsZnVuY3Rpb24oYSl7dGhpcy5wYXJlbnROb2RlLmluc2VydEJlZm9y
ZShhLHRoaXMpfSk7aWYoYXJndW1lbnRzLmxlbmd0aCl7dmFyIGE9ZChhcmd1bWVudHNbMF0pO2Eu
cHVzaC5hcHBseShhLHRoaXMudG9BcnJheSgpKTtyZXR1cm4gdGhpcy5wdXNoU3RhY2soYSwiYmVm
b3JlIixhcmd1bWVudHMpfX0sYWZ0ZXI6ZnVuY3Rpb24oKXtpZih0aGlzWzBdJiZ0aGlzWzBdLnBh
cmVudE5vZGUpcmV0dXJuIHRoaXMuZG9tTWFuaXAoYXJndW1lbnRzLCExLGZ1bmN0aW9uKGEpe3Ro
aXMucGFyZW50Tm9kZS5pbnNlcnRCZWZvcmUoYSx0aGlzLm5leHRTaWJsaW5nKX0pO2lmKGFyZ3Vt
ZW50cy5sZW5ndGgpe3ZhciBhPXRoaXMucHVzaFN0YWNrKHRoaXMsImFmdGVyIixhcmd1bWVudHMp
O2EucHVzaC5hcHBseShhLGQoYXJndW1lbnRzWzBdKS50b0FycmF5KCkpO3JldHVybiBhfX0scmVt
b3ZlOmZ1bmN0aW9uKGEsYil7Zm9yKHZhciBjPTAsZTsoZT10aGlzW2NdKSE9bnVsbDtjKyspaWYo
IWF8fGQuZmlsdGVyKGEsW2VdKS5sZW5ndGgpIWImJmUubm9kZVR5cGU9PT0xJiYoZC5jbGVhbkRh
dGEoZS5nZXRFbGVtZW50c0J5VGFnTmFtZSgiKiIpKSxkLmNsZWFuRGF0YShbZV0pKSxlLnBhcmVu
dE5vZGUmJmUucGFyZW50Tm9kZS5yZW1vdmVDaGlsZChlKTtyZXR1cm4gdGhpc30sZW1wdHk6ZnVu
Y3Rpb24oKXtmb3IodmFyIGE9MCxiOyhiPXRoaXNbYV0pIT1udWxsO2ErKyl7Yi5ub2RlVHlwZT09
PTEmJmQuY2xlYW5EYXRhKGIuZ2V0RWxlbWVudHNCeVRhZ05hbWUoIioiKSk7d2hpbGUoYi5maXJz
dENoaWxkKWIucmVtb3ZlQ2hpbGQoYi5maXJzdENoaWxkKX1yZXR1cm4gdGhpc30sY2xvbmU6ZnVu
Y3Rpb24oYSxiKXthPWE9PW51bGw/ITA6YSxiPWI9PW51bGw/YTpiO3JldHVybiB0aGlzLm1hcChm
dW5jdGlvbigpe3JldHVybiBkLmNsb25lKHRoaXMsYSxiKX0pfSxodG1sOmZ1bmN0aW9uKGEpe2lm
KGE9PT1iKXJldHVybiB0aGlzWzBdJiZ0aGlzWzBdLm5vZGVUeXBlPT09MT90aGlzWzBdLmlubmVy
SFRNTC5yZXBsYWNlKFAsIiIpOm51bGw7aWYodHlwZW9mIGEhPT0ic3RyaW5nInx8Vi50ZXN0KGEp
fHwhZC5zdXBwb3J0LmxlYWRpbmdXaGl0ZXNwYWNlJiZRLnRlc3QoYSl8fFhbKFMuZXhlYyhhKXx8
WyIiLCIiXSlbMV0udG9Mb3dlckNhc2UoKV0pZC5pc0Z1bmN0aW9uKGEpP3RoaXMuZWFjaChmdW5j
dGlvbihiKXt2YXIgYz1kKHRoaXMpO2MuaHRtbChhLmNhbGwodGhpcyxiLGMuaHRtbCgpKSl9KTp0
aGlzLmVtcHR5KCkuYXBwZW5kKGEpO2Vsc2V7YT1hLnJlcGxhY2UoUiwiPCQxPjwvJDI+Iik7dHJ5
e2Zvcih2YXIgYz0wLGU9dGhpcy5sZW5ndGg7YzxlO2MrKyl0aGlzW2NdLm5vZGVUeXBlPT09MSYm
KGQuY2xlYW5EYXRhKHRoaXNbY10uZ2V0RWxlbWVudHNCeVRhZ05hbWUoIioiKSksdGhpc1tjXS5p
bm5lckhUTUw9YSl9Y2F0Y2goZil7dGhpcy5lbXB0eSgpLmFwcGVuZChhKX19cmV0dXJuIHRoaXN9
LHJlcGxhY2VXaXRoOmZ1bmN0aW9uKGEpe2lmKHRoaXNbMF0mJnRoaXNbMF0ucGFyZW50Tm9kZSl7
aWYoZC5pc0Z1bmN0aW9uKGEpKXJldHVybiB0aGlzLmVhY2goZnVuY3Rpb24oYil7dmFyIGM9ZCh0
aGlzKSxlPWMuaHRtbCgpO2MucmVwbGFjZVdpdGgoYS5jYWxsKHRoaXMsYixlKSl9KTt0eXBlb2Yg
YSE9PSJzdHJpbmciJiYoYT1kKGEpLmRldGFjaCgpKTtyZXR1cm4gdGhpcy5lYWNoKGZ1bmN0aW9u
KCl7dmFyIGI9dGhpcy5uZXh0U2libGluZyxjPXRoaXMucGFyZW50Tm9kZTtkKHRoaXMpLnJlbW92
ZSgpLGI/ZChiKS5iZWZvcmUoYSk6ZChjKS5hcHBlbmQoYSl9KX1yZXR1cm4gdGhpcy5wdXNoU3Rh
Y2soZChkLmlzRnVuY3Rpb24oYSk/YSgpOmEpLCJyZXBsYWNlV2l0aCIsYSl9LGRldGFjaDpmdW5j
dGlvbihhKXtyZXR1cm4gdGhpcy5yZW1vdmUoYSwhMCl9LGRvbU1hbmlwOmZ1bmN0aW9uKGEsYyxl
KXt2YXIgZixnLGgsaSxqPWFbMF0saz1bXTtpZighZC5zdXBwb3J0LmNoZWNrQ2xvbmUmJmFyZ3Vt
ZW50cy5sZW5ndGg9PT0zJiZ0eXBlb2Ygaj09PSJzdHJpbmciJiZXLnRlc3QoaikpcmV0dXJuIHRo
aXMuZWFjaChmdW5jdGlvbigpe2QodGhpcykuZG9tTWFuaXAoYSxjLGUsITApfSk7aWYoZC5pc0Z1
bmN0aW9uKGopKXJldHVybiB0aGlzLmVhY2goZnVuY3Rpb24oZil7dmFyIGc9ZCh0aGlzKTthWzBd
PWouY2FsbCh0aGlzLGYsYz9nLmh0bWwoKTpiKSxnLmRvbU1hbmlwKGEsYyxlKX0pO2lmKHRoaXNb
MF0pe2k9aiYmai5wYXJlbnROb2RlLGQuc3VwcG9ydC5wYXJlbnROb2RlJiZpJiZpLm5vZGVUeXBl
PT09MTEmJmkuY2hpbGROb2Rlcy5sZW5ndGg9PT10aGlzLmxlbmd0aD9mPXtmcmFnbWVudDppfTpm
PWQuYnVpbGRGcmFnbWVudChhLHRoaXMsayksaD1mLmZyYWdtZW50LGguY2hpbGROb2Rlcy5sZW5n
dGg9PT0xP2c9aD1oLmZpcnN0Q2hpbGQ6Zz1oLmZpcnN0Q2hpbGQ7aWYoZyl7Yz1jJiZkLm5vZGVO
YW1lKGcsInRyIik7Zm9yKHZhciBsPTAsbT10aGlzLmxlbmd0aCxuPW0tMTtsPG07bCsrKWUuY2Fs
bChjP1kodGhpc1tsXSxnKTp0aGlzW2xdLGYuY2FjaGVhYmxlfHxtPjEmJmw8bj9kLmNsb25lKGgs
ITAsITApOmgpfWsubGVuZ3RoJiZkLmVhY2goayxfKX1yZXR1cm4gdGhpc319KSxkLmJ1aWxkRnJh
Z21lbnQ9ZnVuY3Rpb24oYSxiLGUpe3ZhciBmLGcsaCxpPWImJmJbMF0/YlswXS5vd25lckRvY3Vt
ZW50fHxiWzBdOmM7YS5sZW5ndGg9PT0xJiZ0eXBlb2YgYVswXT09PSJzdHJpbmciJiZhWzBdLmxl
bmd0aDw1MTImJmk9PT1jJiZhWzBdLmNoYXJBdCgwKT09PSI8IiYmIVYudGVzdChhWzBdKSYmKGQu
c3VwcG9ydC5jaGVja0Nsb25lfHwhVy50ZXN0KGFbMF0pKSYmKGc9ITAsaD1kLmZyYWdtZW50c1th
WzBdXSxoJiYoaCE9PTEmJihmPWgpKSksZnx8KGY9aS5jcmVhdGVEb2N1bWVudEZyYWdtZW50KCks
ZC5jbGVhbihhLGksZixlKSksZyYmKGQuZnJhZ21lbnRzW2FbMF1dPWg/ZjoxKTtyZXR1cm57ZnJh
Z21lbnQ6ZixjYWNoZWFibGU6Z319LGQuZnJhZ21lbnRzPXt9LGQuZWFjaCh7YXBwZW5kVG86ImFw
cGVuZCIscHJlcGVuZFRvOiJwcmVwZW5kIixpbnNlcnRCZWZvcmU6ImJlZm9yZSIsaW5zZXJ0QWZ0
ZXI6ImFmdGVyIixyZXBsYWNlQWxsOiJyZXBsYWNlV2l0aCJ9LGZ1bmN0aW9uKGEsYil7ZC5mblth
XT1mdW5jdGlvbihjKXt2YXIgZT1bXSxmPWQoYyksZz10aGlzLmxlbmd0aD09PTEmJnRoaXNbMF0u
cGFyZW50Tm9kZTtpZihnJiZnLm5vZGVUeXBlPT09MTEmJmcuY2hpbGROb2Rlcy5sZW5ndGg9PT0x
JiZmLmxlbmd0aD09PTEpe2ZbYl0odGhpc1swXSk7cmV0dXJuIHRoaXN9Zm9yKHZhciBoPTAsaT1m
Lmxlbmd0aDtoPGk7aCsrKXt2YXIgaj0oaD4wP3RoaXMuY2xvbmUoITApOnRoaXMpLmdldCgpO2Qo
ZltoXSlbYl0oaiksZT1lLmNvbmNhdChqKX1yZXR1cm4gdGhpcy5wdXNoU3RhY2soZSxhLGYuc2Vs
ZWN0b3IpfX0pLGQuZXh0ZW5kKHtjbG9uZTpmdW5jdGlvbihhLGIsYyl7dmFyIGU9YS5jbG9uZU5v
ZGUoITApLGYsZyxoO2lmKCFkLnN1cHBvcnQubm9DbG9uZUV2ZW50JiYoYS5ub2RlVHlwZT09PTF8
fGEubm9kZVR5cGU9PT0xMSkmJiFkLmlzWE1MRG9jKGEpKXtmPWEuZ2V0RWxlbWVudHNCeVRhZ05h
bWUoIioiKSxnPWUuZ2V0RWxlbWVudHNCeVRhZ05hbWUoIioiKTtmb3IoaD0wO2ZbaF07KytoKSQo
ZltoXSxnW2hdKTskKGEsZSl9aWYoYil7WihhLGUpO2lmKGMmJiJnZXRFbGVtZW50c0J5VGFnTmFt
ZSJpbiBhKXtmPWEuZ2V0RWxlbWVudHNCeVRhZ05hbWUoIioiKSxnPWUuZ2V0RWxlbWVudHNCeVRh
Z05hbWUoIioiKTtpZihmLmxlbmd0aClmb3IoaD0wO2ZbaF07KytoKVooZltoXSxnW2hdKX19cmV0
dXJuIGV9LGNsZWFuOmZ1bmN0aW9uKGEsYixlLGYpe2I9Ynx8Yyx0eXBlb2YgYi5jcmVhdGVFbGVt
ZW50PT09InVuZGVmaW5lZCImJihiPWIub3duZXJEb2N1bWVudHx8YlswXSYmYlswXS5vd25lckRv
Y3VtZW50fHxjKTt2YXIgZz1bXTtmb3IodmFyIGg9MCxpOyhpPWFbaF0pIT1udWxsO2grKyl7dHlw
ZW9mIGk9PT0ibnVtYmVyIiYmKGkrPSIiKTtpZighaSljb250aW51ZTtpZih0eXBlb2YgaSE9PSJz
dHJpbmcifHxVLnRlc3QoaSkpe2lmKHR5cGVvZiBpPT09InN0cmluZyIpe2k9aS5yZXBsYWNlKFIs
IjwkMT48LyQyPiIpO3ZhciBqPShTLmV4ZWMoaSl8fFsiIiwiIl0pWzFdLnRvTG93ZXJDYXNlKCks
az1YW2pdfHxYLl9kZWZhdWx0LGw9a1swXSxtPWIuY3JlYXRlRWxlbWVudCgiZGl2Iik7bS5pbm5l
ckhUTUw9a1sxXStpK2tbMl07d2hpbGUobC0tKW09bS5sYXN0Q2hpbGQ7aWYoIWQuc3VwcG9ydC50
Ym9keSl7dmFyIG49VC50ZXN0KGkpLG89aj09PSJ0YWJsZSImJiFuP20uZmlyc3RDaGlsZCYmbS5m
aXJzdENoaWxkLmNoaWxkTm9kZXM6a1sxXT09PSI8dGFibGU+IiYmIW4/bS5jaGlsZE5vZGVzOltd
O2Zvcih2YXIgcD1vLmxlbmd0aC0xO3A+PTA7LS1wKWQubm9kZU5hbWUob1twXSwidGJvZHkiKSYm
IW9bcF0uY2hpbGROb2Rlcy5sZW5ndGgmJm9bcF0ucGFyZW50Tm9kZS5yZW1vdmVDaGlsZChvW3Bd
KX0hZC5zdXBwb3J0LmxlYWRpbmdXaGl0ZXNwYWNlJiZRLnRlc3QoaSkmJm0uaW5zZXJ0QmVmb3Jl
KGIuY3JlYXRlVGV4dE5vZGUoUS5leGVjKGkpWzBdKSxtLmZpcnN0Q2hpbGQpLGk9bS5jaGlsZE5v
ZGVzfX1lbHNlIGk9Yi5jcmVhdGVUZXh0Tm9kZShpKTtpLm5vZGVUeXBlP2cucHVzaChpKTpnPWQu
bWVyZ2UoZyxpKX1pZihlKWZvcihoPTA7Z1toXTtoKyspIWZ8fCFkLm5vZGVOYW1lKGdbaF0sInNj
cmlwdCIpfHxnW2hdLnR5cGUmJmdbaF0udHlwZS50b0xvd2VyQ2FzZSgpIT09InRleHQvamF2YXNj
cmlwdCI/KGdbaF0ubm9kZVR5cGU9PT0xJiZnLnNwbGljZS5hcHBseShnLFtoKzEsMF0uY29uY2F0
KGQubWFrZUFycmF5KGdbaF0uZ2V0RWxlbWVudHNCeVRhZ05hbWUoInNjcmlwdCIpKSkpLGUuYXBw
ZW5kQ2hpbGQoZ1toXSkpOmYucHVzaChnW2hdLnBhcmVudE5vZGU/Z1toXS5wYXJlbnROb2RlLnJl
bW92ZUNoaWxkKGdbaF0pOmdbaF0pO3JldHVybiBnfSxjbGVhbkRhdGE6ZnVuY3Rpb24oYSl7dmFy
IGIsYyxlPWQuY2FjaGUsZj1kLmV4cGFuZG8sZz1kLmV2ZW50LnNwZWNpYWwsaD1kLnN1cHBvcnQu
ZGVsZXRlRXhwYW5kbztmb3IodmFyIGk9MCxqOyhqPWFbaV0pIT1udWxsO2krKyl7aWYoai5ub2Rl
TmFtZSYmZC5ub0RhdGFbai5ub2RlTmFtZS50b0xvd2VyQ2FzZSgpXSljb250aW51ZTtjPWpbZC5l
eHBhbmRvXTtpZihjKXtiPWVbY10mJmVbY11bZl07aWYoYiYmYi5ldmVudHMpe2Zvcih2YXIgayBp
biBiLmV2ZW50cylnW2tdP2QuZXZlbnQucmVtb3ZlKGosayk6ZC5yZW1vdmVFdmVudChqLGssYi5o
YW5kbGUpO2IuaGFuZGxlJiYoYi5oYW5kbGUuZWxlbT1udWxsKX1oP2RlbGV0ZSBqW2QuZXhwYW5k
b106ai5yZW1vdmVBdHRyaWJ1dGUmJmoucmVtb3ZlQXR0cmlidXRlKGQuZXhwYW5kbyksZGVsZXRl
IGVbY119fX19KTt2YXIgYmE9L2FscGhhXChbXildKlwpL2ksYmI9L29wYWNpdHk9KFteKV0qKS8s
YmM9Ly0oW2Etel0pL2lnLGJkPS8oW0EtWl0pL2csYmU9L14tP1xkKyg/OnB4KT8kL2ksYmY9L14t
P1xkLyxiZz17cG9zaXRpb246ImFic29sdXRlIix2aXNpYmlsaXR5OiJoaWRkZW4iLGRpc3BsYXk6
ImJsb2NrIn0sYmg9WyJMZWZ0IiwiUmlnaHQiXSxiaT1bIlRvcCIsIkJvdHRvbSJdLGJqLGJrLGJs
LGJtPWZ1bmN0aW9uKGEsYil7cmV0dXJuIGIudG9VcHBlckNhc2UoKX07ZC5mbi5jc3M9ZnVuY3Rp
b24oYSxjKXtpZihhcmd1bWVudHMubGVuZ3RoPT09MiYmYz09PWIpcmV0dXJuIHRoaXM7cmV0dXJu
IGQuYWNjZXNzKHRoaXMsYSxjLCEwLGZ1bmN0aW9uKGEsYyxlKXtyZXR1cm4gZSE9PWI/ZC5zdHls
ZShhLGMsZSk6ZC5jc3MoYSxjKX0pfSxkLmV4dGVuZCh7Y3NzSG9va3M6e29wYWNpdHk6e2dldDpm
dW5jdGlvbihhLGIpe2lmKGIpe3ZhciBjPWJqKGEsIm9wYWNpdHkiLCJvcGFjaXR5Iik7cmV0dXJu
IGM9PT0iIj8iMSI6Y31yZXR1cm4gYS5zdHlsZS5vcGFjaXR5fX19LGNzc051bWJlcjp7ekluZGV4
OiEwLGZvbnRXZWlnaHQ6ITAsb3BhY2l0eTohMCx6b29tOiEwLGxpbmVIZWlnaHQ6ITB9LGNzc1By
b3BzOnsiZmxvYXQiOmQuc3VwcG9ydC5jc3NGbG9hdD8iY3NzRmxvYXQiOiJzdHlsZUZsb2F0In0s
c3R5bGU6ZnVuY3Rpb24oYSxjLGUsZil7aWYoYSYmYS5ub2RlVHlwZSE9PTMmJmEubm9kZVR5cGUh
PT04JiZhLnN0eWxlKXt2YXIgZyxoPWQuY2FtZWxDYXNlKGMpLGk9YS5zdHlsZSxqPWQuY3NzSG9v
a3NbaF07Yz1kLmNzc1Byb3BzW2hdfHxoO2lmKGU9PT1iKXtpZihqJiYiZ2V0ImluIGomJihnPWou
Z2V0KGEsITEsZikpIT09YilyZXR1cm4gZztyZXR1cm4gaVtjXX1pZih0eXBlb2YgZT09PSJudW1i
ZXIiJiZpc05hTihlKXx8ZT09bnVsbClyZXR1cm47dHlwZW9mIGU9PT0ibnVtYmVyIiYmIWQuY3Nz
TnVtYmVyW2hdJiYoZSs9InB4Iik7aWYoIWp8fCEoInNldCJpbiBqKXx8KGU9ai5zZXQoYSxlKSkh
PT1iKXRyeXtpW2NdPWV9Y2F0Y2goayl7fX19LGNzczpmdW5jdGlvbihhLGMsZSl7dmFyIGYsZz1k
LmNhbWVsQ2FzZShjKSxoPWQuY3NzSG9va3NbZ107Yz1kLmNzc1Byb3BzW2ddfHxnO2lmKGgmJiJn
ZXQiaW4gaCYmKGY9aC5nZXQoYSwhMCxlKSkhPT1iKXJldHVybiBmO2lmKGJqKXJldHVybiBiaihh
LGMsZyl9LHN3YXA6ZnVuY3Rpb24oYSxiLGMpe3ZhciBkPXt9O2Zvcih2YXIgZSBpbiBiKWRbZV09
YS5zdHlsZVtlXSxhLnN0eWxlW2VdPWJbZV07Yy5jYWxsKGEpO2ZvcihlIGluIGIpYS5zdHlsZVtl
XT1kW2VdfSxjYW1lbENhc2U6ZnVuY3Rpb24oYSl7cmV0dXJuIGEucmVwbGFjZShiYyxibSl9fSks
ZC5jdXJDU1M9ZC5jc3MsZC5lYWNoKFsiaGVpZ2h0Iiwid2lkdGgiXSxmdW5jdGlvbihhLGIpe2Qu
Y3NzSG9va3NbYl09e2dldDpmdW5jdGlvbihhLGMsZSl7dmFyIGY7aWYoYyl7YS5vZmZzZXRXaWR0
aCE9PTA/Zj1ibihhLGIsZSk6ZC5zd2FwKGEsYmcsZnVuY3Rpb24oKXtmPWJuKGEsYixlKX0pO2lm
KGY8PTApe2Y9YmooYSxiLGIpLGY9PT0iMHB4IiYmYmwmJihmPWJsKGEsYixiKSk7aWYoZiE9bnVs
bClyZXR1cm4gZj09PSIifHxmPT09ImF1dG8iPyIwcHgiOmZ9aWYoZjwwfHxmPT1udWxsKXtmPWEu
c3R5bGVbYl07cmV0dXJuIGY9PT0iInx8Zj09PSJhdXRvIj8iMHB4IjpmfXJldHVybiB0eXBlb2Yg
Zj09PSJzdHJpbmciP2Y6ZisicHgifX0sc2V0OmZ1bmN0aW9uKGEsYil7aWYoIWJlLnRlc3QoYikp
cmV0dXJuIGI7Yj1wYXJzZUZsb2F0KGIpO2lmKGI+PTApcmV0dXJuIGIrInB4In19fSksZC5zdXBw
b3J0Lm9wYWNpdHl8fChkLmNzc0hvb2tzLm9wYWNpdHk9e2dldDpmdW5jdGlvbihhLGIpe3JldHVy
biBiYi50ZXN0KChiJiZhLmN1cnJlbnRTdHlsZT9hLmN1cnJlbnRTdHlsZS5maWx0ZXI6YS5zdHls
ZS5maWx0ZXIpfHwiIik/cGFyc2VGbG9hdChSZWdFeHAuJDEpLzEwMCsiIjpiPyIxIjoiIn0sc2V0
OmZ1bmN0aW9uKGEsYil7dmFyIGM9YS5zdHlsZTtjLnpvb209MTt2YXIgZT1kLmlzTmFOKGIpPyIi
OiJhbHBoYShvcGFjaXR5PSIrYioxMDArIikiLGY9Yy5maWx0ZXJ8fCIiO2MuZmlsdGVyPWJhLnRl
c3QoZik/Zi5yZXBsYWNlKGJhLGUpOmMuZmlsdGVyKyIgIitlfX0pLGMuZGVmYXVsdFZpZXcmJmMu
ZGVmYXVsdFZpZXcuZ2V0Q29tcHV0ZWRTdHlsZSYmKGJrPWZ1bmN0aW9uKGEsYyxlKXt2YXIgZixn
LGg7ZT1lLnJlcGxhY2UoYmQsIi0kMSIpLnRvTG93ZXJDYXNlKCk7aWYoIShnPWEub3duZXJEb2N1
bWVudC5kZWZhdWx0VmlldykpcmV0dXJuIGI7aWYoaD1nLmdldENvbXB1dGVkU3R5bGUoYSxudWxs
KSlmPWguZ2V0UHJvcGVydHlWYWx1ZShlKSxmPT09IiImJiFkLmNvbnRhaW5zKGEub3duZXJEb2N1
bWVudC5kb2N1bWVudEVsZW1lbnQsYSkmJihmPWQuc3R5bGUoYSxlKSk7cmV0dXJuIGZ9KSxjLmRv
Y3VtZW50RWxlbWVudC5jdXJyZW50U3R5bGUmJihibD1mdW5jdGlvbihhLGIpe3ZhciBjLGQ9YS5j
dXJyZW50U3R5bGUmJmEuY3VycmVudFN0eWxlW2JdLGU9YS5ydW50aW1lU3R5bGUmJmEucnVudGlt
ZVN0eWxlW2JdLGY9YS5zdHlsZTshYmUudGVzdChkKSYmYmYudGVzdChkKSYmKGM9Zi5sZWZ0LGUm
JihhLnJ1bnRpbWVTdHlsZS5sZWZ0PWEuY3VycmVudFN0eWxlLmxlZnQpLGYubGVmdD1iPT09ImZv
bnRTaXplIj8iMWVtIjpkfHwwLGQ9Zi5waXhlbExlZnQrInB4IixmLmxlZnQ9YyxlJiYoYS5ydW50
aW1lU3R5bGUubGVmdD1lKSk7cmV0dXJuIGQ9PT0iIj8iYXV0byI6ZH0pLGJqPWJrfHxibCxkLmV4
cHImJmQuZXhwci5maWx0ZXJzJiYoZC5leHByLmZpbHRlcnMuaGlkZGVuPWZ1bmN0aW9uKGEpe3Zh
ciBiPWEub2Zmc2V0V2lkdGgsYz1hLm9mZnNldEhlaWdodDtyZXR1cm4gYj09PTAmJmM9PT0wfHwh
ZC5zdXBwb3J0LnJlbGlhYmxlSGlkZGVuT2Zmc2V0cyYmKGEuc3R5bGUuZGlzcGxheXx8ZC5jc3Mo
YSwiZGlzcGxheSIpKT09PSJub25lIn0sZC5leHByLmZpbHRlcnMudmlzaWJsZT1mdW5jdGlvbihh
KXtyZXR1cm4hZC5leHByLmZpbHRlcnMuaGlkZGVuKGEpfSk7dmFyIGJvPS8lMjAvZyxicD0vXFtc
XSQvLGJxPS9ccj9cbi9nLGJyPS8jLiokLyxicz0vXiguKj8pOlxzKiguKj8pXHI/JC9tZyxidD0v
Xig/OmNvbG9yfGRhdGV8ZGF0ZXRpbWV8ZW1haWx8aGlkZGVufG1vbnRofG51bWJlcnxwYXNzd29y
ZHxyYW5nZXxzZWFyY2h8dGVsfHRleHR8dGltZXx1cmx8d2VlaykkL2ksYnU9L14oPzpHRVR8SEVB
RCkkLyxidj0vXlwvXC8vLGJ3PS9cPy8sYng9LzxzY3JpcHRcYltePF0qKD86KD8hPFwvc2NyaXB0
Pik8W148XSopKjxcL3NjcmlwdD4vZ2ksYnk9L14oPzpzZWxlY3R8dGV4dGFyZWEpL2ksYno9L1xz
Ky8sYkE9LyhbPyZdKV89W14mXSovLGJCPS9eKFx3KzopXC9cLyhbXlwvPyM6XSspKD86OihcZCsp
KT8vLGJDPWQuZm4ubG9hZCxiRD17fSxiRT17fTtkLmZuLmV4dGVuZCh7bG9hZDpmdW5jdGlvbihh
LGIsYyl7aWYodHlwZW9mIGEhPT0ic3RyaW5nIiYmYkMpcmV0dXJuIGJDLmFwcGx5KHRoaXMsYXJn
dW1lbnRzKTtpZighdGhpcy5sZW5ndGgpcmV0dXJuIHRoaXM7dmFyIGU9YS5pbmRleE9mKCIgIik7
aWYoZT49MCl7dmFyIGY9YS5zbGljZShlLGEubGVuZ3RoKTthPWEuc2xpY2UoMCxlKX12YXIgZz0i
R0VUIjtiJiYoZC5pc0Z1bmN0aW9uKGIpPyhjPWIsYj1udWxsKTp0eXBlb2YgYj09PSJvYmplY3Qi
JiYoYj1kLnBhcmFtKGIsZC5hamF4U2V0dGluZ3MudHJhZGl0aW9uYWwpLGc9IlBPU1QiKSk7dmFy
IGg9dGhpcztkLmFqYXgoe3VybDphLHR5cGU6ZyxkYXRhVHlwZToiaHRtbCIsZGF0YTpiLGNvbXBs
ZXRlOmZ1bmN0aW9uKGEsYixlKXtlPWEucmVzcG9uc2VUZXh0LGEuaXNSZXNvbHZlZCgpJiYoYS5k
b25lKGZ1bmN0aW9uKGEpe2U9YX0pLGguaHRtbChmP2QoIjxkaXY+IikuYXBwZW5kKGUucmVwbGFj
ZShieCwiIikpLmZpbmQoZik6ZSkpLGMmJmguZWFjaChjLFtlLGIsYV0pfX0pO3JldHVybiB0aGlz
fSxzZXJpYWxpemU6ZnVuY3Rpb24oKXtyZXR1cm4gZC5wYXJhbSh0aGlzLnNlcmlhbGl6ZUFycmF5
KCkpfSxzZXJpYWxpemVBcnJheTpmdW5jdGlvbigpe3JldHVybiB0aGlzLm1hcChmdW5jdGlvbigp
e3JldHVybiB0aGlzLmVsZW1lbnRzP2QubWFrZUFycmF5KHRoaXMuZWxlbWVudHMpOnRoaXN9KS5m
aWx0ZXIoZnVuY3Rpb24oKXtyZXR1cm4gdGhpcy5uYW1lJiYhdGhpcy5kaXNhYmxlZCYmKHRoaXMu
Y2hlY2tlZHx8YnkudGVzdCh0aGlzLm5vZGVOYW1lKXx8YnQudGVzdCh0aGlzLnR5cGUpKX0pLm1h
cChmdW5jdGlvbihhLGIpe3ZhciBjPWQodGhpcykudmFsKCk7cmV0dXJuIGM9PW51bGw/bnVsbDpk
LmlzQXJyYXkoYyk/ZC5tYXAoYyxmdW5jdGlvbihhLGMpe3JldHVybntuYW1lOmIubmFtZSx2YWx1
ZTphLnJlcGxhY2UoYnEsIlxyXG4iKX19KTp7bmFtZTpiLm5hbWUsdmFsdWU6Yy5yZXBsYWNlKGJx
LCJcclxuIil9fSkuZ2V0KCl9fSksZC5lYWNoKCJhamF4U3RhcnQgYWpheFN0b3AgYWpheENvbXBs
ZXRlIGFqYXhFcnJvciBhamF4U3VjY2VzcyBhamF4U2VuZCIuc3BsaXQoIiAiKSxmdW5jdGlvbihh
LGIpe2QuZm5bYl09ZnVuY3Rpb24oYSl7cmV0dXJuIHRoaXMuYmluZChiLGEpfX0pLGQuZWFjaChb
ImdldCIsInBvc3QiXSxmdW5jdGlvbihhLGIpe2RbYl09ZnVuY3Rpb24oYSxjLGUsZil7ZC5pc0Z1
bmN0aW9uKGMpJiYoZj1mfHxlLGU9YyxjPW51bGwpO3JldHVybiBkLmFqYXgoe3R5cGU6Yix1cmw6
YSxkYXRhOmMsc3VjY2VzczplLGRhdGFUeXBlOmZ9KX19KSxkLmV4dGVuZCh7Z2V0U2NyaXB0OmZ1
bmN0aW9uKGEsYil7cmV0dXJuIGQuZ2V0KGEsbnVsbCxiLCJzY3JpcHQiKX0sZ2V0SlNPTjpmdW5j
dGlvbihhLGIsYyl7cmV0dXJuIGQuZ2V0KGEsYixjLCJqc29uIil9LGFqYXhTZXR1cDpmdW5jdGlv
bihhKXtkLmV4dGVuZCghMCxkLmFqYXhTZXR0aW5ncyxhKSxhLmNvbnRleHQmJihkLmFqYXhTZXR0
aW5ncy5jb250ZXh0PWEuY29udGV4dCl9LGFqYXhTZXR0aW5nczp7dXJsOmxvY2F0aW9uLmhyZWYs
Z2xvYmFsOiEwLHR5cGU6IkdFVCIsY29udGVudFR5cGU6ImFwcGxpY2F0aW9uL3gtd3d3LWZvcm0t
dXJsZW5jb2RlZCIscHJvY2Vzc0RhdGE6ITAsYXN5bmM6ITAsYWNjZXB0czp7eG1sOiJhcHBsaWNh
dGlvbi94bWwsIHRleHQveG1sIixodG1sOiJ0ZXh0L2h0bWwiLHRleHQ6InRleHQvcGxhaW4iLGpz
b246ImFwcGxpY2F0aW9uL2pzb24sIHRleHQvamF2YXNjcmlwdCIsIioiOiIqLyoifSxjb250ZW50
czp7eG1sOi94bWwvLGh0bWw6L2h0bWwvLGpzb246L2pzb24vfSxyZXNwb25zZUZpZWxkczp7eG1s
OiJyZXNwb25zZVhNTCIsdGV4dDoicmVzcG9uc2VUZXh0In0sY29udmVydGVyczp7IiogdGV4dCI6
YS5TdHJpbmcsInRleHQgaHRtbCI6ITAsInRleHQganNvbiI6ZC5wYXJzZUpTT04sInRleHQgeG1s
IjpkLnBhcnNlWE1MfX0sYWpheFByZWZpbHRlcjpiRihiRCksYWpheFRyYW5zcG9ydDpiRihiRSks
YWpheDpmdW5jdGlvbihhLGUpe2Z1bmN0aW9uIHcoYSxjLGUsbCl7aWYodCE9PTIpe3Q9MixwJiZj
bGVhclRpbWVvdXQocCksbz1iLG09bHx8IiIsdi5yZWFkeVN0YXRlPWE/NDowO3ZhciBuLHEscixz
PWU/YkkoZix2LGUpOmIsdSx3O2lmKGE+PTIwMCYmYTwzMDB8fGE9PT0zMDQpe2lmKGYuaWZNb2Rp
ZmllZCl7aWYodT12LmdldFJlc3BvbnNlSGVhZGVyKCJMYXN0LU1vZGlmaWVkIikpZC5sYXN0TW9k
aWZpZWRbZi51cmxdPXU7aWYodz12LmdldFJlc3BvbnNlSGVhZGVyKCJFdGFnIikpZC5ldGFnW2Yu
dXJsXT13fWlmKGE9PT0zMDQpYz0ibm90bW9kaWZpZWQiLG49ITA7ZWxzZSB0cnl7cT1iSihmLHMp
LGM9InN1Y2Nlc3MiLG49ITB9Y2F0Y2goeCl7Yz0icGFyc2VyZXJyb3IiLHI9eH19ZWxzZSByPWMs
YSYmKGM9ImVycm9yIixhPDAmJihhPTApKTt2LnN0YXR1cz1hLHYuc3RhdHVzVGV4dD1jLG4/aS5y
ZXNvbHZlV2l0aChnLFtxLGMsdl0pOmkucmVqZWN0V2l0aChnLFt2LGMscl0pLHYuc3RhdHVzQ29k
ZShrKSxrPWIsZi5nbG9iYWwmJmgudHJpZ2dlcigiYWpheCIrKG4/IlN1Y2Nlc3MiOiJFcnJvciIp
LFt2LGYsbj9xOnJdKSxqLnJlc29sdmVXaXRoKGcsW3YsY10pLGYuZ2xvYmFsJiYoaC50cmlnZ2Vy
KCJhamF4Q29tcGxldGUiLFt2LGZdKSwtLWQuYWN0aXZlfHxkLmV2ZW50LnRyaWdnZXIoImFqYXhT
dG9wIikpfX10eXBlb2YgZSE9PSJvYmplY3QiJiYoZT1hLGE9YiksZT1lfHx7fTt2YXIgZj1kLmV4
dGVuZCghMCx7fSxkLmFqYXhTZXR0aW5ncyxlKSxnPShmLmNvbnRleHQ9KCJjb250ZXh0ImluIGU/
ZTpkLmFqYXhTZXR0aW5ncykuY29udGV4dCl8fGYsaD1nPT09Zj9kLmV2ZW50OmQoZyksaT1kLkRl
ZmVycmVkKCksaj1kLl9EZWZlcnJlZCgpLGs9Zi5zdGF0dXNDb2RlfHx7fSxsPXt9LG0sbixvLHAs
cT1jLmxvY2F0aW9uLHI9cS5wcm90b2NvbHx8Imh0dHA6IixzLHQ9MCx1LHY9e3JlYWR5U3RhdGU6
MCxzZXRSZXF1ZXN0SGVhZGVyOmZ1bmN0aW9uKGEsYil7dD09PTAmJihsW2EudG9Mb3dlckNhc2Uo
KV09Yik7cmV0dXJuIHRoaXN9LGdldEFsbFJlc3BvbnNlSGVhZGVyczpmdW5jdGlvbigpe3JldHVy
biB0PT09Mj9tOm51bGx9LGdldFJlc3BvbnNlSGVhZGVyOmZ1bmN0aW9uKGEpe3ZhciBiO2lmKHQ9
PT0yKXtpZighbil7bj17fTt3aGlsZShiPWJzLmV4ZWMobSkpbltiWzFdLnRvTG93ZXJDYXNlKCld
PWJbMl19Yj1uW2EudG9Mb3dlckNhc2UoKV19cmV0dXJuIGJ8fG51bGx9LGFib3J0OmZ1bmN0aW9u
KGEpe2E9YXx8ImFib3J0IixvJiZvLmFib3J0KGEpLHcoMCxhKTtyZXR1cm4gdGhpc319O2kucHJv
bWlzZSh2KSx2LnN1Y2Nlc3M9di5kb25lLHYuZXJyb3I9di5mYWlsLHYuY29tcGxldGU9ai5kb25l
LHYuc3RhdHVzQ29kZT1mdW5jdGlvbihhKXtpZihhKXt2YXIgYjtpZih0PDIpZm9yKGIgaW4gYSlr
W2JdPVtrW2JdLGFbYl1dO2Vsc2UgYj1hW3Yuc3RhdHVzXSx2LnRoZW4oYixiKX1yZXR1cm4gdGhp
c30sZi51cmw9KCIiKyhhfHxmLnVybCkpLnJlcGxhY2UoYnIsIiIpLnJlcGxhY2UoYnYscisiLy8i
KSxmLmRhdGFUeXBlcz1kLnRyaW0oZi5kYXRhVHlwZXx8IioiKS50b0xvd2VyQ2FzZSgpLnNwbGl0
KGJ6KSxmLmNyb3NzRG9tYWlufHwocz1iQi5leGVjKGYudXJsLnRvTG93ZXJDYXNlKCkpLGYuY3Jv
c3NEb21haW49cyYmKHNbMV0hPXJ8fHNbMl0hPXEuaG9zdG5hbWV8fChzWzNdfHwoc1sxXT09PSJo
dHRwOiI/ODA6NDQzKSkhPShxLnBvcnR8fChyPT09Imh0dHA6Ij84MDo0NDMpKSkpLGYuZGF0YSYm
Zi5wcm9jZXNzRGF0YSYmdHlwZW9mIGYuZGF0YSE9PSJzdHJpbmciJiYoZi5kYXRhPWQucGFyYW0o
Zi5kYXRhLGYudHJhZGl0aW9uYWwpKSxiRyhiRCxmLGUsdiksZi50eXBlPWYudHlwZS50b1VwcGVy
Q2FzZSgpLGYuaGFzQ29udGVudD0hYnUudGVzdChmLnR5cGUpLGYuZ2xvYmFsJiZkLmFjdGl2ZSsr
PT09MCYmZC5ldmVudC50cmlnZ2VyKCJhamF4U3RhcnQiKTtpZighZi5oYXNDb250ZW50KXtmLmRh
dGEmJihmLnVybCs9KGJ3LnRlc3QoZi51cmwpPyImIjoiPyIpK2YuZGF0YSk7aWYoZi5jYWNoZT09
PSExKXt2YXIgeD1kLm5vdygpLHk9Zi51cmwucmVwbGFjZShiQSwiJDFfPSIreCk7Zi51cmw9eSso
eT09PWYudXJsPyhidy50ZXN0KGYudXJsKT8iJiI6Ij8iKSsiXz0iK3g6IiIpfX1pZihmLmRhdGEm
JmYuaGFzQ29udGVudCYmZi5jb250ZW50VHlwZSE9PSExfHxlLmNvbnRlbnRUeXBlKWxbImNvbnRl
bnQtdHlwZSJdPWYuY29udGVudFR5cGU7Zi5pZk1vZGlmaWVkJiYoZC5sYXN0TW9kaWZpZWRbZi51
cmxdJiYobFsiaWYtbW9kaWZpZWQtc2luY2UiXT1kLmxhc3RNb2RpZmllZFtmLnVybF0pLGQuZXRh
Z1tmLnVybF0mJihsWyJpZi1ub25lLW1hdGNoIl09ZC5ldGFnW2YudXJsXSkpLGwuYWNjZXB0PWYu
ZGF0YVR5cGVzWzBdJiZmLmFjY2VwdHNbZi5kYXRhVHlwZXNbMF1dP2YuYWNjZXB0c1tmLmRhdGFU
eXBlc1swXV0rKGYuZGF0YVR5cGVzWzBdIT09IioiPyIsICovKjsgcT0wLjAxIjoiIik6Zi5hY2Nl
cHRzWyIqIl07Zm9yKHUgaW4gZi5oZWFkZXJzKWxbdS50b0xvd2VyQ2FzZSgpXT1mLmhlYWRlcnNb
dV07aWYoIWYuYmVmb3JlU2VuZHx8Zi5iZWZvcmVTZW5kLmNhbGwoZyx2LGYpIT09ITEmJnQhPT0y
KXtmb3IodSBpbiB7c3VjY2VzczoxLGVycm9yOjEsY29tcGxldGU6MX0pdlt1XShmW3VdKTtvPWJH
KGJFLGYsZSx2KTtpZihvKXt0PXYucmVhZHlTdGF0ZT0xLGYuZ2xvYmFsJiZoLnRyaWdnZXIoImFq
YXhTZW5kIixbdixmXSksZi5hc3luYyYmZi50aW1lb3V0PjAmJihwPXNldFRpbWVvdXQoZnVuY3Rp
b24oKXt2LmFib3J0KCJ0aW1lb3V0Iil9LGYudGltZW91dCkpO3RyeXtvLnNlbmQobCx3KX1jYXRj
aCh6KXtzdGF0dXM8Mj93KC0xLHopOmQuZXJyb3Ioeil9fWVsc2UgdygtMSwiTm8gVHJhbnNwb3J0
Iil9ZWxzZSB3KDAsImFib3J0Iiksdj0hMTtyZXR1cm4gdn0scGFyYW06ZnVuY3Rpb24oYSxjKXt2
YXIgZT1bXSxmPWZ1bmN0aW9uKGEsYil7Yj1kLmlzRnVuY3Rpb24oYik/YigpOmIsZVtlLmxlbmd0
aF09ZW5jb2RlVVJJQ29tcG9uZW50KGEpKyI9IitlbmNvZGVVUklDb21wb25lbnQoYil9O2M9PT1i
JiYoYz1kLmFqYXhTZXR0aW5ncy50cmFkaXRpb25hbCk7aWYoZC5pc0FycmF5KGEpfHxhLmpxdWVy
eSlkLmVhY2goYSxmdW5jdGlvbigpe2YodGhpcy5uYW1lLHRoaXMudmFsdWUpfSk7ZWxzZSBmb3Io
dmFyIGcgaW4gYSliSChnLGFbZ10sYyxmKTtyZXR1cm4gZS5qb2luKCImIikucmVwbGFjZShibywi
KyIpfX0pLGQuZXh0ZW5kKHthY3RpdmU6MCxsYXN0TW9kaWZpZWQ6e30sZXRhZzp7fX0pO3ZhciBi
Sz1kLm5vdygpLGJMPS8oXD0pXD8oJnwkKXwoKVw/XD8oKS9pO2QuYWpheFNldHVwKHtqc29ucDoi
Y2FsbGJhY2siLGpzb25wQ2FsbGJhY2s6ZnVuY3Rpb24oKXtyZXR1cm4gZC5leHBhbmRvKyJfIiti
SysrfX0pLGQuYWpheFByZWZpbHRlcigianNvbiBqc29ucCIsZnVuY3Rpb24oYixjLGUpe2U9dHlw
ZW9mIGIuZGF0YT09PSJzdHJpbmciO2lmKGIuZGF0YVR5cGVzWzBdPT09Impzb25wInx8Yy5qc29u
cENhbGxiYWNrfHxjLmpzb25wIT1udWxsfHxiLmpzb25wIT09ITEmJihiTC50ZXN0KGIudXJsKXx8
ZSYmYkwudGVzdChiLmRhdGEpKSl7dmFyIGYsZz1iLmpzb25wQ2FsbGJhY2s9ZC5pc0Z1bmN0aW9u
KGIuanNvbnBDYWxsYmFjayk/Yi5qc29ucENhbGxiYWNrKCk6Yi5qc29ucENhbGxiYWNrLGg9YVtn
XSxpPWIudXJsLGo9Yi5kYXRhLGs9IiQxIitnKyIkMiI7Yi5qc29ucCE9PSExJiYoaT1pLnJlcGxh
Y2UoYkwsayksYi51cmw9PT1pJiYoZSYmKGo9ai5yZXBsYWNlKGJMLGspKSxiLmRhdGE9PT1qJiYo
aSs9KC9cPy8udGVzdChpKT8iJiI6Ij8iKStiLmpzb25wKyI9IitnKSkpLGIudXJsPWksYi5kYXRh
PWosYVtnXT1mdW5jdGlvbihhKXtmPVthXX0sYi5jb21wbGV0ZT1bZnVuY3Rpb24oKXthW2ddPWg7
aWYoaClmJiZkLmlzRnVuY3Rpb24oaCkmJmFbZ10oZlswXSk7ZWxzZSB0cnl7ZGVsZXRlIGFbZ119
Y2F0Y2goYil7fX0sYi5jb21wbGV0ZV0sYi5jb252ZXJ0ZXJzWyJzY3JpcHQganNvbiJdPWZ1bmN0
aW9uKCl7Znx8ZC5lcnJvcihnKyIgd2FzIG5vdCBjYWxsZWQiKTtyZXR1cm4gZlswXX0sYi5kYXRh
VHlwZXNbMF09Impzb24iO3JldHVybiJzY3JpcHQifX0pLGQuYWpheFNldHVwKHthY2NlcHRzOntz
Y3JpcHQ6InRleHQvamF2YXNjcmlwdCwgYXBwbGljYXRpb24vamF2YXNjcmlwdCJ9LGNvbnRlbnRz
OntzY3JpcHQ6L2phdmFzY3JpcHQvfSxjb252ZXJ0ZXJzOnsidGV4dCBzY3JpcHQiOmZ1bmN0aW9u
KGEpe2QuZ2xvYmFsRXZhbChhKTtyZXR1cm4gYX19fSksZC5hamF4UHJlZmlsdGVyKCJzY3JpcHQi
LGZ1bmN0aW9uKGEpe2EuY2FjaGU9PT1iJiYoYS5jYWNoZT0hMSksYS5jcm9zc0RvbWFpbiYmKGEu
dHlwZT0iR0VUIixhLmdsb2JhbD0hMSl9KSxkLmFqYXhUcmFuc3BvcnQoInNjcmlwdCIsZnVuY3Rp
b24oYSl7aWYoYS5jcm9zc0RvbWFpbil7dmFyIGQsZT1jLmdldEVsZW1lbnRzQnlUYWdOYW1lKCJo
ZWFkIilbMF18fGMuZG9jdW1lbnRFbGVtZW50O3JldHVybntzZW5kOmZ1bmN0aW9uKGYsZyl7ZD1j
LmNyZWF0ZUVsZW1lbnQoInNjcmlwdCIpLGQuYXN5bmM9ImFzeW5jIixhLnNjcmlwdENoYXJzZXQm
JihkLmNoYXJzZXQ9YS5zY3JpcHRDaGFyc2V0KSxkLnNyYz1hLnVybCxkLm9ubG9hZD1kLm9ucmVh
ZHlzdGF0ZWNoYW5nZT1mdW5jdGlvbihhLGMpe2lmKCFkLnJlYWR5U3RhdGV8fC9sb2FkZWR8Y29t
cGxldGUvLnRlc3QoZC5yZWFkeVN0YXRlKSlkLm9ubG9hZD1kLm9ucmVhZHlzdGF0ZWNoYW5nZT1u
dWxsLGUmJmQucGFyZW50Tm9kZSYmZS5yZW1vdmVDaGlsZChkKSxkPWIsY3x8ZygyMDAsInN1Y2Nl
c3MiKX0sZS5pbnNlcnRCZWZvcmUoZCxlLmZpcnN0Q2hpbGQpfSxhYm9ydDpmdW5jdGlvbigpe2Qm
JmQub25sb2FkKDAsMSl9fX19KTt2YXIgYk09ZC5ub3coKSxiTj17fSxiTyxiUDtkLmFqYXhTZXR0
aW5ncy54aHI9YS5BY3RpdmVYT2JqZWN0P2Z1bmN0aW9uKCl7aWYoYS5sb2NhdGlvbi5wcm90b2Nv
bCE9PSJmaWxlOiIpdHJ5e3JldHVybiBuZXcgYS5YTUxIdHRwUmVxdWVzdH1jYXRjaChiKXt9dHJ5
e3JldHVybiBuZXcgYS5BY3RpdmVYT2JqZWN0KCJNaWNyb3NvZnQuWE1MSFRUUCIpfWNhdGNoKGMp
e319OmZ1bmN0aW9uKCl7cmV0dXJuIG5ldyBhLlhNTEh0dHBSZXF1ZXN0fTt0cnl7YlA9ZC5hamF4
U2V0dGluZ3MueGhyKCl9Y2F0Y2goYlEpe31kLnN1cHBvcnQuYWpheD0hIWJQLGQuc3VwcG9ydC5j
b3JzPWJQJiYid2l0aENyZWRlbnRpYWxzImluIGJQLGJQPWIsZC5zdXBwb3J0LmFqYXgmJmQuYWph
eFRyYW5zcG9ydChmdW5jdGlvbihiKXtpZighYi5jcm9zc0RvbWFpbnx8ZC5zdXBwb3J0LmNvcnMp
e3ZhciBjO3JldHVybntzZW5kOmZ1bmN0aW9uKGUsZil7Yk98fChiTz0xLGQoYSkuYmluZCgidW5s
b2FkIixmdW5jdGlvbigpe2QuZWFjaChiTixmdW5jdGlvbihhLGIpe2Iub25yZWFkeXN0YXRlY2hh
bmdlJiZiLm9ucmVhZHlzdGF0ZWNoYW5nZSgxKX0pfSkpO3ZhciBnPWIueGhyKCksaDtiLnVzZXJu
YW1lP2cub3BlbihiLnR5cGUsYi51cmwsYi5hc3luYyxiLnVzZXJuYW1lLGIucGFzc3dvcmQpOmcu
b3BlbihiLnR5cGUsYi51cmwsYi5hc3luYyksKCFiLmNyb3NzRG9tYWlufHxiLmhhc0NvbnRlbnQp
JiYhZVsieC1yZXF1ZXN0ZWQtd2l0aCJdJiYoZVsieC1yZXF1ZXN0ZWQtd2l0aCJdPSJYTUxIdHRw
UmVxdWVzdCIpO3RyeXtkLmVhY2goZSxmdW5jdGlvbihhLGIpe2cuc2V0UmVxdWVzdEhlYWRlcihh
LGIpfSl9Y2F0Y2goaSl7fWcuc2VuZChiLmhhc0NvbnRlbnQmJmIuZGF0YXx8bnVsbCksYz1mdW5j
dGlvbihhLGUpe2lmKGMmJihlfHxnLnJlYWR5U3RhdGU9PT00KSl7Yz0wLGgmJihnLm9ucmVhZHlz
dGF0ZWNoYW5nZT1kLm5vb3AsZGVsZXRlIGJOW2hdKTtpZihlKWcucmVhZHlTdGF0ZSE9PTQmJmcu
YWJvcnQoKTtlbHNle3ZhciBpPWcuc3RhdHVzLGosaz1nLmdldEFsbFJlc3BvbnNlSGVhZGVycygp
LGw9e30sbT1nLnJlc3BvbnNlWE1MO20mJm0uZG9jdW1lbnRFbGVtZW50JiYobC54bWw9bSksbC50
ZXh0PWcucmVzcG9uc2VUZXh0O3RyeXtqPWcuc3RhdHVzVGV4dH1jYXRjaChuKXtqPSIifWk9aT09
PTA/IWIuY3Jvc3NEb21haW58fGo/az8zMDQ6MDozMDI6aT09MTIyMz8yMDQ6aSxmKGksaixsLGsp
fX19LGIuYXN5bmMmJmcucmVhZHlTdGF0ZSE9PTQ/KGg9Yk0rKyxiTltoXT1nLGcub25yZWFkeXN0
YXRlY2hhbmdlPWMpOmMoKX0sYWJvcnQ6ZnVuY3Rpb24oKXtjJiZjKDAsMSl9fX19KTt2YXIgYlI9
e30sYlM9L14oPzp0b2dnbGV8c2hvd3xoaWRlKSQvLGJUPS9eKFsrXC1dPSk/KFtcZCsuXC1dKyko
W2EteiVdKikkL2ksYlUsYlY9W1siaGVpZ2h0IiwibWFyZ2luVG9wIiwibWFyZ2luQm90dG9tIiwi
cGFkZGluZ1RvcCIsInBhZGRpbmdCb3R0b20iXSxbIndpZHRoIiwibWFyZ2luTGVmdCIsIm1hcmdp
blJpZ2h0IiwicGFkZGluZ0xlZnQiLCJwYWRkaW5nUmlnaHQiXSxbIm9wYWNpdHkiXV07ZC5mbi5l
eHRlbmQoe3Nob3c6ZnVuY3Rpb24oYSxiLGMpe3ZhciBlLGY7aWYoYXx8YT09PTApcmV0dXJuIHRo
aXMuYW5pbWF0ZShiVygic2hvdyIsMyksYSxiLGMpO2Zvcih2YXIgZz0wLGg9dGhpcy5sZW5ndGg7
ZzxoO2crKyllPXRoaXNbZ10sZj1lLnN0eWxlLmRpc3BsYXksIWQuX2RhdGEoZSwib2xkZGlzcGxh
eSIpJiZmPT09Im5vbmUiJiYoZj1lLnN0eWxlLmRpc3BsYXk9IiIpLGY9PT0iIiYmZC5jc3MoZSwi
ZGlzcGxheSIpPT09Im5vbmUiJiZkLl9kYXRhKGUsIm9sZGRpc3BsYXkiLGJYKGUubm9kZU5hbWUp
KTtmb3IoZz0wO2c8aDtnKyspe2U9dGhpc1tnXSxmPWUuc3R5bGUuZGlzcGxheTtpZihmPT09IiJ8
fGY9PT0ibm9uZSIpZS5zdHlsZS5kaXNwbGF5PWQuX2RhdGEoZSwib2xkZGlzcGxheSIpfHwiIn1y
ZXR1cm4gdGhpc30saGlkZTpmdW5jdGlvbihhLGIsYyl7aWYoYXx8YT09PTApcmV0dXJuIHRoaXMu
YW5pbWF0ZShiVygiaGlkZSIsMyksYSxiLGMpO2Zvcih2YXIgZT0wLGY9dGhpcy5sZW5ndGg7ZTxm
O2UrKyl7dmFyIGc9ZC5jc3ModGhpc1tlXSwiZGlzcGxheSIpO2chPT0ibm9uZSImJiFkLl9kYXRh
KHRoaXNbZV0sIm9sZGRpc3BsYXkiKSYmZC5fZGF0YSh0aGlzW2VdLCJvbGRkaXNwbGF5IixnKX1m
b3IoZT0wO2U8ZjtlKyspdGhpc1tlXS5zdHlsZS5kaXNwbGF5PSJub25lIjtyZXR1cm4gdGhpc30s
X3RvZ2dsZTpkLmZuLnRvZ2dsZSx0b2dnbGU6ZnVuY3Rpb24oYSxiLGMpe3ZhciBlPXR5cGVvZiBh
PT09ImJvb2xlYW4iO2QuaXNGdW5jdGlvbihhKSYmZC5pc0Z1bmN0aW9uKGIpP3RoaXMuX3RvZ2ds
ZS5hcHBseSh0aGlzLGFyZ3VtZW50cyk6YT09bnVsbHx8ZT90aGlzLmVhY2goZnVuY3Rpb24oKXt2
YXIgYj1lP2E6ZCh0aGlzKS5pcygiOmhpZGRlbiIpO2QodGhpcylbYj8ic2hvdyI6ImhpZGUiXSgp
fSk6dGhpcy5hbmltYXRlKGJXKCJ0b2dnbGUiLDMpLGEsYixjKTtyZXR1cm4gdGhpc30sZmFkZVRv
OmZ1bmN0aW9uKGEsYixjLGQpe3JldHVybiB0aGlzLmZpbHRlcigiOmhpZGRlbiIpLmNzcygib3Bh
Y2l0eSIsMCkuc2hvdygpLmVuZCgpLmFuaW1hdGUoe29wYWNpdHk6Yn0sYSxjLGQpfSxhbmltYXRl
OmZ1bmN0aW9uKGEsYixjLGUpe3ZhciBmPWQuc3BlZWQoYixjLGUpO2lmKGQuaXNFbXB0eU9iamVj
dChhKSlyZXR1cm4gdGhpcy5lYWNoKGYuY29tcGxldGUpO3JldHVybiB0aGlzW2YucXVldWU9PT0h
MT8iZWFjaCI6InF1ZXVlIl0oZnVuY3Rpb24oKXt2YXIgYj1kLmV4dGVuZCh7fSxmKSxjLGU9dGhp
cy5ub2RlVHlwZT09PTEsZz1lJiZkKHRoaXMpLmlzKCI6aGlkZGVuIiksaD10aGlzO2ZvcihjIGlu
IGEpe3ZhciBpPWQuY2FtZWxDYXNlKGMpO2MhPT1pJiYoYVtpXT1hW2NdLGRlbGV0ZSBhW2NdLGM9
aSk7aWYoYVtjXT09PSJoaWRlIiYmZ3x8YVtjXT09PSJzaG93IiYmIWcpcmV0dXJuIGIuY29tcGxl
dGUuY2FsbCh0aGlzKTtpZihlJiYoYz09PSJoZWlnaHQifHxjPT09IndpZHRoIikpe2Iub3ZlcmZs
b3c9W3RoaXMuc3R5bGUub3ZlcmZsb3csdGhpcy5zdHlsZS5vdmVyZmxvd1gsdGhpcy5zdHlsZS5v
dmVyZmxvd1ldO2lmKGQuY3NzKHRoaXMsImRpc3BsYXkiKT09PSJpbmxpbmUiJiZkLmNzcyh0aGlz
LCJmbG9hdCIpPT09Im5vbmUiKWlmKGQuc3VwcG9ydC5pbmxpbmVCbG9ja05lZWRzTGF5b3V0KXt2
YXIgaj1iWCh0aGlzLm5vZGVOYW1lKTtqPT09ImlubGluZSI/dGhpcy5zdHlsZS5kaXNwbGF5PSJp
bmxpbmUtYmxvY2siOih0aGlzLnN0eWxlLmRpc3BsYXk9ImlubGluZSIsdGhpcy5zdHlsZS56b29t
PTEpfWVsc2UgdGhpcy5zdHlsZS5kaXNwbGF5PSJpbmxpbmUtYmxvY2sifWQuaXNBcnJheShhW2Nd
KSYmKChiLnNwZWNpYWxFYXNpbmc9Yi5zcGVjaWFsRWFzaW5nfHx7fSlbY109YVtjXVsxXSxhW2Nd
PWFbY11bMF0pfWIub3ZlcmZsb3chPW51bGwmJih0aGlzLnN0eWxlLm92ZXJmbG93PSJoaWRkZW4i
KSxiLmN1ckFuaW09ZC5leHRlbmQoe30sYSksZC5lYWNoKGEsZnVuY3Rpb24oYyxlKXt2YXIgZj1u
ZXcgZC5meChoLGIsYyk7aWYoYlMudGVzdChlKSlmW2U9PT0idG9nZ2xlIj9nPyJzaG93IjoiaGlk
ZSI6ZV0oYSk7ZWxzZXt2YXIgaT1iVC5leGVjKGUpLGo9Zi5jdXIoKXx8MDtpZihpKXt2YXIgaz1w
YXJzZUZsb2F0KGlbMl0pLGw9aVszXXx8InB4IjtsIT09InB4IiYmKGQuc3R5bGUoaCxjLChrfHwx
KStsKSxqPShrfHwxKS9mLmN1cigpKmosZC5zdHlsZShoLGMsaitsKSksaVsxXSYmKGs9KGlbMV09
PT0iLT0iPy0xOjEpKmsraiksZi5jdXN0b20oaixrLGwpfWVsc2UgZi5jdXN0b20oaixlLCIiKX19
KTtyZXR1cm4hMH0pfSxzdG9wOmZ1bmN0aW9uKGEsYil7dmFyIGM9ZC50aW1lcnM7YSYmdGhpcy5x
dWV1ZShbXSksdGhpcy5lYWNoKGZ1bmN0aW9uKCl7Zm9yKHZhciBhPWMubGVuZ3RoLTE7YT49MDth
LS0pY1thXS5lbGVtPT09dGhpcyYmKGImJmNbYV0oITApLGMuc3BsaWNlKGEsMSkpfSksYnx8dGhp
cy5kZXF1ZXVlKCk7cmV0dXJuIHRoaXN9fSksZC5lYWNoKHtzbGlkZURvd246YlcoInNob3ciLDEp
LHNsaWRlVXA6YlcoImhpZGUiLDEpLHNsaWRlVG9nZ2xlOmJXKCJ0b2dnbGUiLDEpLGZhZGVJbjp7
b3BhY2l0eToic2hvdyJ9LGZhZGVPdXQ6e29wYWNpdHk6ImhpZGUifSxmYWRlVG9nZ2xlOntvcGFj
aXR5OiJ0b2dnbGUifX0sZnVuY3Rpb24oYSxiKXtkLmZuW2FdPWZ1bmN0aW9uKGEsYyxkKXtyZXR1
cm4gdGhpcy5hbmltYXRlKGIsYSxjLGQpfX0pLGQuZXh0ZW5kKHtzcGVlZDpmdW5jdGlvbihhLGIs
Yyl7dmFyIGU9YSYmdHlwZW9mIGE9PT0ib2JqZWN0Ij9kLmV4dGVuZCh7fSxhKTp7Y29tcGxldGU6
Y3x8IWMmJmJ8fGQuaXNGdW5jdGlvbihhKSYmYSxkdXJhdGlvbjphLGVhc2luZzpjJiZifHxiJiYh
ZC5pc0Z1bmN0aW9uKGIpJiZifTtlLmR1cmF0aW9uPWQuZngub2ZmPzA6dHlwZW9mIGUuZHVyYXRp
b249PT0ibnVtYmVyIj9lLmR1cmF0aW9uOmUuZHVyYXRpb24gaW4gZC5meC5zcGVlZHM/ZC5meC5z
cGVlZHNbZS5kdXJhdGlvbl06ZC5meC5zcGVlZHMuX2RlZmF1bHQsZS5vbGQ9ZS5jb21wbGV0ZSxl
LmNvbXBsZXRlPWZ1bmN0aW9uKCl7ZS5xdWV1ZSE9PSExJiZkKHRoaXMpLmRlcXVldWUoKSxkLmlz
RnVuY3Rpb24oZS5vbGQpJiZlLm9sZC5jYWxsKHRoaXMpfTtyZXR1cm4gZX0sZWFzaW5nOntsaW5l
YXI6ZnVuY3Rpb24oYSxiLGMsZCl7cmV0dXJuIGMrZCphfSxzd2luZzpmdW5jdGlvbihhLGIsYyxk
KXtyZXR1cm4oLU1hdGguY29zKGEqTWF0aC5QSSkvMisuNSkqZCtjfX0sdGltZXJzOltdLGZ4OmZ1
bmN0aW9uKGEsYixjKXt0aGlzLm9wdGlvbnM9Yix0aGlzLmVsZW09YSx0aGlzLnByb3A9YyxiLm9y
aWd8fChiLm9yaWc9e30pfX0pLGQuZngucHJvdG90eXBlPXt1cGRhdGU6ZnVuY3Rpb24oKXt0aGlz
Lm9wdGlvbnMuc3RlcCYmdGhpcy5vcHRpb25zLnN0ZXAuY2FsbCh0aGlzLmVsZW0sdGhpcy5ub3cs
dGhpcyksKGQuZnguc3RlcFt0aGlzLnByb3BdfHxkLmZ4LnN0ZXAuX2RlZmF1bHQpKHRoaXMpfSxj
dXI6ZnVuY3Rpb24oKXtpZih0aGlzLmVsZW1bdGhpcy5wcm9wXSE9bnVsbCYmKCF0aGlzLmVsZW0u
c3R5bGV8fHRoaXMuZWxlbS5zdHlsZVt0aGlzLnByb3BdPT1udWxsKSlyZXR1cm4gdGhpcy5lbGVt
W3RoaXMucHJvcF07dmFyIGE9cGFyc2VGbG9hdChkLmNzcyh0aGlzLmVsZW0sdGhpcy5wcm9wKSk7
cmV0dXJuIGF8fDB9LGN1c3RvbTpmdW5jdGlvbihhLGIsYyl7ZnVuY3Rpb24gZyhhKXtyZXR1cm4g
ZS5zdGVwKGEpfXZhciBlPXRoaXMsZj1kLmZ4O3RoaXMuc3RhcnRUaW1lPWQubm93KCksdGhpcy5z
dGFydD1hLHRoaXMuZW5kPWIsdGhpcy51bml0PWN8fHRoaXMudW5pdHx8InB4Iix0aGlzLm5vdz10
aGlzLnN0YXJ0LHRoaXMucG9zPXRoaXMuc3RhdGU9MCxnLmVsZW09dGhpcy5lbGVtLGcoKSYmZC50
aW1lcnMucHVzaChnKSYmIWJVJiYoYlU9c2V0SW50ZXJ2YWwoZi50aWNrLGYuaW50ZXJ2YWwpKX0s
c2hvdzpmdW5jdGlvbigpe3RoaXMub3B0aW9ucy5vcmlnW3RoaXMucHJvcF09ZC5zdHlsZSh0aGlz
LmVsZW0sdGhpcy5wcm9wKSx0aGlzLm9wdGlvbnMuc2hvdz0hMCx0aGlzLmN1c3RvbSh0aGlzLnBy
b3A9PT0id2lkdGgifHx0aGlzLnByb3A9PT0iaGVpZ2h0Ij8xOjAsdGhpcy5jdXIoKSksZCh0aGlz
LmVsZW0pLnNob3coKX0saGlkZTpmdW5jdGlvbigpe3RoaXMub3B0aW9ucy5vcmlnW3RoaXMucHJv
cF09ZC5zdHlsZSh0aGlzLmVsZW0sdGhpcy5wcm9wKSx0aGlzLm9wdGlvbnMuaGlkZT0hMCx0aGlz
LmN1c3RvbSh0aGlzLmN1cigpLDApfSxzdGVwOmZ1bmN0aW9uKGEpe3ZhciBiPWQubm93KCksYz0h
MDtpZihhfHxiPj10aGlzLm9wdGlvbnMuZHVyYXRpb24rdGhpcy5zdGFydFRpbWUpe3RoaXMubm93
PXRoaXMuZW5kLHRoaXMucG9zPXRoaXMuc3RhdGU9MSx0aGlzLnVwZGF0ZSgpLHRoaXMub3B0aW9u
cy5jdXJBbmltW3RoaXMucHJvcF09ITA7Zm9yKHZhciBlIGluIHRoaXMub3B0aW9ucy5jdXJBbmlt
KXRoaXMub3B0aW9ucy5jdXJBbmltW2VdIT09ITAmJihjPSExKTtpZihjKXtpZih0aGlzLm9wdGlv
bnMub3ZlcmZsb3chPW51bGwmJiFkLnN1cHBvcnQuc2hyaW5rV3JhcEJsb2Nrcyl7dmFyIGY9dGhp
cy5lbGVtLGc9dGhpcy5vcHRpb25zO2QuZWFjaChbIiIsIlgiLCJZIl0sZnVuY3Rpb24oYSxiKXtm
LnN0eWxlWyJvdmVyZmxvdyIrYl09Zy5vdmVyZmxvd1thXX0pfXRoaXMub3B0aW9ucy5oaWRlJiZk
KHRoaXMuZWxlbSkuaGlkZSgpO2lmKHRoaXMub3B0aW9ucy5oaWRlfHx0aGlzLm9wdGlvbnMuc2hv
dylmb3IodmFyIGggaW4gdGhpcy5vcHRpb25zLmN1ckFuaW0pZC5zdHlsZSh0aGlzLmVsZW0saCx0
aGlzLm9wdGlvbnMub3JpZ1toXSk7dGhpcy5vcHRpb25zLmNvbXBsZXRlLmNhbGwodGhpcy5lbGVt
KX1yZXR1cm4hMX12YXIgaT1iLXRoaXMuc3RhcnRUaW1lO3RoaXMuc3RhdGU9aS90aGlzLm9wdGlv
bnMuZHVyYXRpb247dmFyIGo9dGhpcy5vcHRpb25zLnNwZWNpYWxFYXNpbmcmJnRoaXMub3B0aW9u
cy5zcGVjaWFsRWFzaW5nW3RoaXMucHJvcF0saz10aGlzLm9wdGlvbnMuZWFzaW5nfHwoZC5lYXNp
bmcuc3dpbmc/InN3aW5nIjoibGluZWFyIik7dGhpcy5wb3M9ZC5lYXNpbmdbanx8a10odGhpcy5z
dGF0ZSxpLDAsMSx0aGlzLm9wdGlvbnMuZHVyYXRpb24pLHRoaXMubm93PXRoaXMuc3RhcnQrKHRo
aXMuZW5kLXRoaXMuc3RhcnQpKnRoaXMucG9zLHRoaXMudXBkYXRlKCk7cmV0dXJuITB9fSxkLmV4
dGVuZChkLmZ4LHt0aWNrOmZ1bmN0aW9uKCl7dmFyIGE9ZC50aW1lcnM7Zm9yKHZhciBiPTA7Yjxh
Lmxlbmd0aDtiKyspYVtiXSgpfHxhLnNwbGljZShiLS0sMSk7YS5sZW5ndGh8fGQuZnguc3RvcCgp
fSxpbnRlcnZhbDoxMyxzdG9wOmZ1bmN0aW9uKCl7Y2xlYXJJbnRlcnZhbChiVSksYlU9bnVsbH0s
c3BlZWRzOntzbG93OjYwMCxmYXN0OjIwMCxfZGVmYXVsdDo0MDB9LHN0ZXA6e29wYWNpdHk6ZnVu
Y3Rpb24oYSl7ZC5zdHlsZShhLmVsZW0sIm9wYWNpdHkiLGEubm93KX0sX2RlZmF1bHQ6ZnVuY3Rp
b24oYSl7YS5lbGVtLnN0eWxlJiZhLmVsZW0uc3R5bGVbYS5wcm9wXSE9bnVsbD9hLmVsZW0uc3R5
bGVbYS5wcm9wXT0oYS5wcm9wPT09IndpZHRoInx8YS5wcm9wPT09ImhlaWdodCI/TWF0aC5tYXgo
MCxhLm5vdyk6YS5ub3cpK2EudW5pdDphLmVsZW1bYS5wcm9wXT1hLm5vd319fSksZC5leHByJiZk
LmV4cHIuZmlsdGVycyYmKGQuZXhwci5maWx0ZXJzLmFuaW1hdGVkPWZ1bmN0aW9uKGEpe3JldHVy
biBkLmdyZXAoZC50aW1lcnMsZnVuY3Rpb24oYil7cmV0dXJuIGE9PT1iLmVsZW19KS5sZW5ndGh9
KTt2YXIgYlk9L150KD86YWJsZXxkfGgpJC9pLGJaPS9eKD86Ym9keXxodG1sKSQvaTsiZ2V0Qm91
bmRpbmdDbGllbnRSZWN0ImluIGMuZG9jdW1lbnRFbGVtZW50P2QuZm4ub2Zmc2V0PWZ1bmN0aW9u
KGEpe3ZhciBiPXRoaXNbMF0sYztpZihhKXJldHVybiB0aGlzLmVhY2goZnVuY3Rpb24oYil7ZC5v
ZmZzZXQuc2V0T2Zmc2V0KHRoaXMsYSxiKX0pO2lmKCFifHwhYi5vd25lckRvY3VtZW50KXJldHVy
biBudWxsO2lmKGI9PT1iLm93bmVyRG9jdW1lbnQuYm9keSlyZXR1cm4gZC5vZmZzZXQuYm9keU9m
ZnNldChiKTt0cnl7Yz1iLmdldEJvdW5kaW5nQ2xpZW50UmVjdCgpfWNhdGNoKGUpe312YXIgZj1i
Lm93bmVyRG9jdW1lbnQsZz1mLmRvY3VtZW50RWxlbWVudDtpZighY3x8IWQuY29udGFpbnMoZyxi
KSlyZXR1cm4gYz97dG9wOmMudG9wLGxlZnQ6Yy5sZWZ0fTp7dG9wOjAsbGVmdDowfTt2YXIgaD1m
LmJvZHksaT1iJChmKSxqPWcuY2xpZW50VG9wfHxoLmNsaWVudFRvcHx8MCxrPWcuY2xpZW50TGVm
dHx8aC5jbGllbnRMZWZ0fHwwLGw9aS5wYWdlWU9mZnNldHx8ZC5zdXBwb3J0LmJveE1vZGVsJiZn
LnNjcm9sbFRvcHx8aC5zY3JvbGxUb3AsbT1pLnBhZ2VYT2Zmc2V0fHxkLnN1cHBvcnQuYm94TW9k
ZWwmJmcuc2Nyb2xsTGVmdHx8aC5zY3JvbGxMZWZ0LG49Yy50b3ArbC1qLG89Yy5sZWZ0K20tazty
ZXR1cm57dG9wOm4sbGVmdDpvfX06ZC5mbi5vZmZzZXQ9ZnVuY3Rpb24oYSl7dmFyIGI9dGhpc1sw
XTtpZihhKXJldHVybiB0aGlzLmVhY2goZnVuY3Rpb24oYil7ZC5vZmZzZXQuc2V0T2Zmc2V0KHRo
aXMsYSxiKX0pO2lmKCFifHwhYi5vd25lckRvY3VtZW50KXJldHVybiBudWxsO2lmKGI9PT1iLm93
bmVyRG9jdW1lbnQuYm9keSlyZXR1cm4gZC5vZmZzZXQuYm9keU9mZnNldChiKTtkLm9mZnNldC5p
bml0aWFsaXplKCk7dmFyIGMsZT1iLm9mZnNldFBhcmVudCxmPWIsZz1iLm93bmVyRG9jdW1lbnQs
aD1nLmRvY3VtZW50RWxlbWVudCxpPWcuYm9keSxqPWcuZGVmYXVsdFZpZXcsaz1qP2ouZ2V0Q29t
cHV0ZWRTdHlsZShiLG51bGwpOmIuY3VycmVudFN0eWxlLGw9Yi5vZmZzZXRUb3AsbT1iLm9mZnNl
dExlZnQ7d2hpbGUoKGI9Yi5wYXJlbnROb2RlKSYmYiE9PWkmJmIhPT1oKXtpZihkLm9mZnNldC5z
dXBwb3J0c0ZpeGVkUG9zaXRpb24mJmsucG9zaXRpb249PT0iZml4ZWQiKWJyZWFrO2M9aj9qLmdl
dENvbXB1dGVkU3R5bGUoYixudWxsKTpiLmN1cnJlbnRTdHlsZSxsLT1iLnNjcm9sbFRvcCxtLT1i
LnNjcm9sbExlZnQsYj09PWUmJihsKz1iLm9mZnNldFRvcCxtKz1iLm9mZnNldExlZnQsZC5vZmZz
ZXQuZG9lc05vdEFkZEJvcmRlciYmKCFkLm9mZnNldC5kb2VzQWRkQm9yZGVyRm9yVGFibGVBbmRD
ZWxsc3x8IWJZLnRlc3QoYi5ub2RlTmFtZSkpJiYobCs9cGFyc2VGbG9hdChjLmJvcmRlclRvcFdp
ZHRoKXx8MCxtKz1wYXJzZUZsb2F0KGMuYm9yZGVyTGVmdFdpZHRoKXx8MCksZj1lLGU9Yi5vZmZz
ZXRQYXJlbnQpLGQub2Zmc2V0LnN1YnRyYWN0c0JvcmRlckZvck92ZXJmbG93Tm90VmlzaWJsZSYm
Yy5vdmVyZmxvdyE9PSJ2aXNpYmxlIiYmKGwrPXBhcnNlRmxvYXQoYy5ib3JkZXJUb3BXaWR0aCl8
fDAsbSs9cGFyc2VGbG9hdChjLmJvcmRlckxlZnRXaWR0aCl8fDApLGs9Y31pZihrLnBvc2l0aW9u
PT09InJlbGF0aXZlInx8ay5wb3NpdGlvbj09PSJzdGF0aWMiKWwrPWkub2Zmc2V0VG9wLG0rPWku
b2Zmc2V0TGVmdDtkLm9mZnNldC5zdXBwb3J0c0ZpeGVkUG9zaXRpb24mJmsucG9zaXRpb249PT0i
Zml4ZWQiJiYobCs9TWF0aC5tYXgoaC5zY3JvbGxUb3AsaS5zY3JvbGxUb3ApLG0rPU1hdGgubWF4
KGguc2Nyb2xsTGVmdCxpLnNjcm9sbExlZnQpKTtyZXR1cm57dG9wOmwsbGVmdDptfX0sZC5vZmZz
ZXQ9e2luaXRpYWxpemU6ZnVuY3Rpb24oKXt2YXIgYT1jLmJvZHksYj1jLmNyZWF0ZUVsZW1lbnQo
ImRpdiIpLGUsZixnLGgsaT1wYXJzZUZsb2F0KGQuY3NzKGEsIm1hcmdpblRvcCIpKXx8MCxqPSI8
ZGl2IHN0eWxlPSdwb3NpdGlvbjphYnNvbHV0ZTt0b3A6MDtsZWZ0OjA7bWFyZ2luOjA7Ym9yZGVy
OjVweCBzb2xpZCAjMDAwO3BhZGRpbmc6MDt3aWR0aDoxcHg7aGVpZ2h0OjFweDsnPjxkaXY+PC9k
aXY+PC9kaXY+PHRhYmxlIHN0eWxlPSdwb3NpdGlvbjphYnNvbHV0ZTt0b3A6MDtsZWZ0OjA7bWFy
Z2luOjA7Ym9yZGVyOjVweCBzb2xpZCAjMDAwO3BhZGRpbmc6MDt3aWR0aDoxcHg7aGVpZ2h0OjFw
eDsnIGNlbGxwYWRkaW5nPScwJyBjZWxsc3BhY2luZz0nMCc+PHRyPjx0ZD48L3RkPjwvdHI+PC90
YWJsZT4iO2QuZXh0ZW5kKGIuc3R5bGUse3Bvc2l0aW9uOiJhYnNvbHV0ZSIsdG9wOjAsbGVmdDow
LG1hcmdpbjowLGJvcmRlcjowLHdpZHRoOiIxcHgiLGhlaWdodDoiMXB4Iix2aXNpYmlsaXR5OiJo
aWRkZW4ifSksYi5pbm5lckhUTUw9aixhLmluc2VydEJlZm9yZShiLGEuZmlyc3RDaGlsZCksZT1i
LmZpcnN0Q2hpbGQsZj1lLmZpcnN0Q2hpbGQsaD1lLm5leHRTaWJsaW5nLmZpcnN0Q2hpbGQuZmly
c3RDaGlsZCx0aGlzLmRvZXNOb3RBZGRCb3JkZXI9Zi5vZmZzZXRUb3AhPT01LHRoaXMuZG9lc0Fk
ZEJvcmRlckZvclRhYmxlQW5kQ2VsbHM9aC5vZmZzZXRUb3A9PT01LGYuc3R5bGUucG9zaXRpb249
ImZpeGVkIixmLnN0eWxlLnRvcD0iMjBweCIsdGhpcy5zdXBwb3J0c0ZpeGVkUG9zaXRpb249Zi5v
ZmZzZXRUb3A9PT0yMHx8Zi5vZmZzZXRUb3A9PT0xNSxmLnN0eWxlLnBvc2l0aW9uPWYuc3R5bGUu
dG9wPSIiLGUuc3R5bGUub3ZlcmZsb3c9ImhpZGRlbiIsZS5zdHlsZS5wb3NpdGlvbj0icmVsYXRp
dmUiLHRoaXMuc3VidHJhY3RzQm9yZGVyRm9yT3ZlcmZsb3dOb3RWaXNpYmxlPWYub2Zmc2V0VG9w
PT09LTUsdGhpcy5kb2VzTm90SW5jbHVkZU1hcmdpbkluQm9keU9mZnNldD1hLm9mZnNldFRvcCE9
PWksYS5yZW1vdmVDaGlsZChiKSxhPWI9ZT1mPWc9aD1udWxsLGQub2Zmc2V0LmluaXRpYWxpemU9
ZC5ub29wfSxib2R5T2Zmc2V0OmZ1bmN0aW9uKGEpe3ZhciBiPWEub2Zmc2V0VG9wLGM9YS5vZmZz
ZXRMZWZ0O2Qub2Zmc2V0LmluaXRpYWxpemUoKSxkLm9mZnNldC5kb2VzTm90SW5jbHVkZU1hcmdp
bkluQm9keU9mZnNldCYmKGIrPXBhcnNlRmxvYXQoZC5jc3MoYSwibWFyZ2luVG9wIikpfHwwLGMr
PXBhcnNlRmxvYXQoZC5jc3MoYSwibWFyZ2luTGVmdCIpKXx8MCk7cmV0dXJue3RvcDpiLGxlZnQ6
Y319LHNldE9mZnNldDpmdW5jdGlvbihhLGIsYyl7dmFyIGU9ZC5jc3MoYSwicG9zaXRpb24iKTtl
PT09InN0YXRpYyImJihhLnN0eWxlLnBvc2l0aW9uPSJyZWxhdGl2ZSIpO3ZhciBmPWQoYSksZz1m
Lm9mZnNldCgpLGg9ZC5jc3MoYSwidG9wIiksaT1kLmNzcyhhLCJsZWZ0Iiksaj1lPT09ImFic29s
dXRlIiYmZC5pbkFycmF5KCJhdXRvIixbaCxpXSk+LTEsaz17fSxsPXt9LG0sbjtqJiYobD1mLnBv
c2l0aW9uKCkpLG09aj9sLnRvcDpwYXJzZUludChoLDEwKXx8MCxuPWo/bC5sZWZ0OnBhcnNlSW50
KGksMTApfHwwLGQuaXNGdW5jdGlvbihiKSYmKGI9Yi5jYWxsKGEsYyxnKSksYi50b3AhPW51bGwm
JihrLnRvcD1iLnRvcC1nLnRvcCttKSxiLmxlZnQhPW51bGwmJihrLmxlZnQ9Yi5sZWZ0LWcubGVm
dCtuKSwidXNpbmciaW4gYj9iLnVzaW5nLmNhbGwoYSxrKTpmLmNzcyhrKX19LGQuZm4uZXh0ZW5k
KHtwb3NpdGlvbjpmdW5jdGlvbigpe2lmKCF0aGlzWzBdKXJldHVybiBudWxsO3ZhciBhPXRoaXNb
MF0sYj10aGlzLm9mZnNldFBhcmVudCgpLGM9dGhpcy5vZmZzZXQoKSxlPWJaLnRlc3QoYlswXS5u
b2RlTmFtZSk/e3RvcDowLGxlZnQ6MH06Yi5vZmZzZXQoKTtjLnRvcC09cGFyc2VGbG9hdChkLmNz
cyhhLCJtYXJnaW5Ub3AiKSl8fDAsYy5sZWZ0LT1wYXJzZUZsb2F0KGQuY3NzKGEsIm1hcmdpbkxl
ZnQiKSl8fDAsZS50b3ArPXBhcnNlRmxvYXQoZC5jc3MoYlswXSwiYm9yZGVyVG9wV2lkdGgiKSl8
fDAsZS5sZWZ0Kz1wYXJzZUZsb2F0KGQuY3NzKGJbMF0sImJvcmRlckxlZnRXaWR0aCIpKXx8MDty
ZXR1cm57dG9wOmMudG9wLWUudG9wLGxlZnQ6Yy5sZWZ0LWUubGVmdH19LG9mZnNldFBhcmVudDpm
dW5jdGlvbigpe3JldHVybiB0aGlzLm1hcChmdW5jdGlvbigpe3ZhciBhPXRoaXMub2Zmc2V0UGFy
ZW50fHxjLmJvZHk7d2hpbGUoYSYmKCFiWi50ZXN0KGEubm9kZU5hbWUpJiZkLmNzcyhhLCJwb3Np
dGlvbiIpPT09InN0YXRpYyIpKWE9YS5vZmZzZXRQYXJlbnQ7cmV0dXJuIGF9KX19KSxkLmVhY2go
WyJMZWZ0IiwiVG9wIl0sZnVuY3Rpb24oYSxjKXt2YXIgZT0ic2Nyb2xsIitjO2QuZm5bZV09ZnVu
Y3Rpb24oYyl7dmFyIGY9dGhpc1swXSxnO2lmKCFmKXJldHVybiBudWxsO2lmKGMhPT1iKXJldHVy
biB0aGlzLmVhY2goZnVuY3Rpb24oKXtnPWIkKHRoaXMpLGc/Zy5zY3JvbGxUbyhhP2QoZykuc2Ny
b2xsTGVmdCgpOmMsYT9jOmQoZykuc2Nyb2xsVG9wKCkpOnRoaXNbZV09Y30pO2c9YiQoZik7cmV0
dXJuIGc/InBhZ2VYT2Zmc2V0ImluIGc/Z1thPyJwYWdlWU9mZnNldCI6InBhZ2VYT2Zmc2V0Il06
ZC5zdXBwb3J0LmJveE1vZGVsJiZnLmRvY3VtZW50LmRvY3VtZW50RWxlbWVudFtlXXx8Zy5kb2N1
bWVudC5ib2R5W2VdOmZbZV19fSksZC5lYWNoKFsiSGVpZ2h0IiwiV2lkdGgiXSxmdW5jdGlvbihh
LGMpe3ZhciBlPWMudG9Mb3dlckNhc2UoKTtkLmZuWyJpbm5lciIrY109ZnVuY3Rpb24oKXtyZXR1
cm4gdGhpc1swXT9wYXJzZUZsb2F0KGQuY3NzKHRoaXNbMF0sZSwicGFkZGluZyIpKTpudWxsfSxk
LmZuWyJvdXRlciIrY109ZnVuY3Rpb24oYSl7cmV0dXJuIHRoaXNbMF0/cGFyc2VGbG9hdChkLmNz
cyh0aGlzWzBdLGUsYT8ibWFyZ2luIjoiYm9yZGVyIikpOm51bGx9LGQuZm5bZV09ZnVuY3Rpb24o
YSl7dmFyIGY9dGhpc1swXTtpZighZilyZXR1cm4gYT09bnVsbD9udWxsOnRoaXM7aWYoZC5pc0Z1
bmN0aW9uKGEpKXJldHVybiB0aGlzLmVhY2goZnVuY3Rpb24oYil7dmFyIGM9ZCh0aGlzKTtjW2Vd
KGEuY2FsbCh0aGlzLGIsY1tlXSgpKSl9KTtpZihkLmlzV2luZG93KGYpKXt2YXIgZz1mLmRvY3Vt
ZW50LmRvY3VtZW50RWxlbWVudFsiY2xpZW50IitjXTtyZXR1cm4gZi5kb2N1bWVudC5jb21wYXRN
b2RlPT09IkNTUzFDb21wYXQiJiZnfHxmLmRvY3VtZW50LmJvZHlbImNsaWVudCIrY118fGd9aWYo
Zi5ub2RlVHlwZT09PTkpcmV0dXJuIE1hdGgubWF4KGYuZG9jdW1lbnRFbGVtZW50WyJjbGllbnQi
K2NdLGYuYm9keVsic2Nyb2xsIitjXSxmLmRvY3VtZW50RWxlbWVudFsic2Nyb2xsIitjXSxmLmJv
ZHlbIm9mZnNldCIrY10sZi5kb2N1bWVudEVsZW1lbnRbIm9mZnNldCIrY10pO2lmKGE9PT1iKXt2
YXIgaD1kLmNzcyhmLGUpLGk9cGFyc2VGbG9hdChoKTtyZXR1cm4gZC5pc05hTihpKT9oOml9cmV0
dXJuIHRoaXMuY3NzKGUsdHlwZW9mIGE9PT0ic3RyaW5nIj9hOmErInB4Iil9fSl9KSh3aW5kb3cp
Owo=

@@ js/lang-apollo.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJjb20iLC9eI1te
XHJcbl0qLyxudWxsLCIjIl0sWyJwbG4iLC9eW1x0XG5cciBceEEwXSsvLG51bGwsIlx0XG5cciBc
dTAwYTAiXSxbInN0ciIsL15cIig/OlteXCJcXF18XFxbXHNcU10pKig/OlwifCQpLyxudWxsLCci
J11dLFtbImt3ZCIsL14oPzpBRFN8QUR8QVVHfEJaRnxCWk1GfENBRXxDQUZ8Q0F8Q0NTfENPTXxD
U3xEQVN8RENBfERDT018RENTfERET1VCTHxESU18RE9VQkxFfERUQ0J8RFRDRnxEVnxEWENIfEVE
UlVQVHxFWFRFTkR8SU5DUnxJTkRFWHxORFh8SU5ISU5UfExYQ0h8TUFTS3xNU0t8TVB8TVNVfE5P
T1B8T1ZTS3xRWENIfFJBTkR8UkVBRHxSRUxJTlR8UkVTVU1FfFJFVFVSTnxST1J8UlhPUnxTUVVB
UkV8U1V8VENSfFRDQUF8T1ZTS3xUQ0Z8VEN8VFN8V0FORHxXT1J8V1JJVEV8WENIfFhMUXxYWEFM
UXxaTHxaUXxBRER8QURafFNVQnxTVVp8TVBZfE1QUnxNUFp8RFZQfENPTXxBQlN8Q0xBfENMWnxM
RFF8U1RPfFNUUXxBTFN8TExTfExSU3xUUkF8VFNRfFRNSXxUT1Z8QVhUfFRJWHxETFl8SU5QfE9V
VClccy8sCm51bGxdLFsidHlwIiwvXig/Oi0/R0VOQURSfD1NSU5VU3wyQkNBRFJ8Vk58Qk9GfE1N
fC0/MkNBRFJ8LT9bMS02XUROQURSfEFEUkVTfEJCQ09OfFtTRV0/QkFOS1w9P3xCTE9DS3xCTktT
VU18RT9DQURSfENPVU5UXCo/fDI/REVDXCo/fC0/RE5DSEFOfC0/RE5QVFJ8RVFVQUxTfEVSQVNF
fE1FTU9SWXwyP09DVHxSRU1BRFJ8U0VUTE9DfFNVQlJPfE9SR3xCU1N8QkVTfFNZTnxFUVV8REVG
SU5FfEVORClccy8sbnVsbF0sWyJsaXQiLC9eXCcoPzotKig/Olx3fFxcW1x4MjEtXHg3ZV0pKD86
W1x3LV0qfFxcW1x4MjEtXHg3ZV0pWz0hP10/KT8vXSxbInBsbiIsL14tKig/OlshLXpfXXxcXFtc
eDIxLVx4N2VdKSg/Oltcdy1dKnxcXFtceDIxLVx4N2VdKVs9IT9dPy9pXSxbInB1biIsL15bXlx3
XHRcblxyIFx4QTAoKVwiXFxcJztdKy9dXSksWyJhcG9sbG8iLCJhZ2MiLCJhZWEiXSk=

@@ js/lang-css.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eWyBc
dFxyXG5cZl0rLyxudWxsLCIgXHRcclxuXHUwMDBjIl1dLFtbInN0ciIsL15cIig/OlteXG5cclxm
XFxcIl18XFwoPzpcclxuP3xcbnxcZil8XFxbXHNcU10pKlwiLyxudWxsXSxbInN0ciIsL15cJyg/
OlteXG5cclxmXFxcJ118XFwoPzpcclxuP3xcbnxcZil8XFxbXHNcU10pKlwnLyxudWxsXSxbImxh
bmctY3NzLXN0ciIsL151cmxcKChbXlwpXCJcJ10qKVwpL2ldLFsia3dkIiwvXig/OnVybHxyZ2J8
XCFpbXBvcnRhbnR8QGltcG9ydHxAcGFnZXxAbWVkaWF8QGNoYXJzZXR8aW5oZXJpdCkoPz1bXlwt
XHddfCQpL2ksbnVsbF0sWyJsYW5nLWNzcy1rdyIsL14oLT8oPzpbX2Etel18KD86XFxbMC05YS1m
XSsgPykpKD86W19hLXowLTlcLV18XFwoPzpcXFswLTlhLWZdKyA/KSkqKVxzKjovaV0sWyJjb20i
LC9eXC9cKlteKl0qXCorKD86W15cLypdW14qXSpcKispKlwvL10sClsiY29tIiwvXig/OjwhLS18
LS1cPikvXSxbImxpdCIsL14oPzpcZCt8XGQqXC5cZCspKD86JXxbYS16XSspPy9pXSxbImxpdCIs
L14jKD86WzAtOWEtZl17M30pezEsMn0vaV0sWyJwbG4iLC9eLT8oPzpbX2Etel18KD86XFxbXGRh
LWZdKyA/KSkoPzpbX2EtelxkXC1dfFxcKD86XFxbXGRhLWZdKyA/KSkqL2ldLFsicHVuIiwvXlte
XHNcd1wnXCJdKy9dXSksWyJjc3MiXSk7UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVT
aW1wbGVMZXhlcihbXSxbWyJrd2QiLC9eLT8oPzpbX2Etel18KD86XFxbXGRhLWZdKyA/KSkoPzpb
X2EtelxkXC1dfFxcKD86XFxbXGRhLWZdKyA/KSkqL2ldXSksWyJjc3Mta3ciXSk7UFIucmVnaXN0
ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbXSxbWyJzdHIiLC9eW15cKVwiXCdd
Ky9dXSksWyJjc3Mtc3RyIl0p

@@ js/lang-hs.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5ceDBCXHgwQ1xyIF0rLyxudWxsLCJcdFxuXHUwMDBiXHUwMDBjXHIgIl0sWyJzdHIiLC9eXCIo
PzpbXlwiXFxcblx4MENccl18XFxbXHNcU10pKig/OlwifCQpLyxudWxsLCciJ10sWyJzdHIiLC9e
XCcoPzpbXlwnXFxcblx4MENccl18XFxbXiZdKVwnPy8sbnVsbCwiJyJdLFsibGl0IiwvXig/OjBv
WzAtN10rfDB4W1xkYS1mXSt8XGQrKD86XC5cZCspPyg/OmVbK1wtXT9cZCspPykvaSxudWxsLCIw
MTIzNDU2Nzg5Il1dLFtbImNvbSIsL14oPzooPzotLSsoPzpbXlxyXG5ceDBDXSopPyl8KD86XHst
KD86W14tXXwtK1teLVx9XSkqLVx9KSkvXSxbImt3ZCIsL14oPzpjYXNlfGNsYXNzfGRhdGF8ZGVm
YXVsdHxkZXJpdmluZ3xkb3xlbHNlfGlmfGltcG9ydHxpbnxpbmZpeHxpbmZpeGx8aW5maXhyfGlu
c3RhbmNlfGxldHxtb2R1bGV8bmV3dHlwZXxvZnx0aGVufHR5cGV8d2hlcmV8XykoPz1bXmEtekEt
WjAtOVwnXXwkKS8sCm51bGxdLFsicGxuIiwvXig/OltBLVpdW1x3XCddKlwuKSpbYS16QS1aXVtc
d1wnXSovXSxbInB1biIsL15bXlx0XG5ceDBCXHgwQ1xyIGEtekEtWjAtOVwnXCJdKy9dXSksWyJo
cyJdKQ==

@@ js/lang-lisp.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJvcG4iLC9eXCgv
LG51bGwsIigiXSxbImNsbyIsL15cKS8sbnVsbCwiKSJdLFsiY29tIiwvXjtbXlxyXG5dKi8sbnVs
bCwiOyJdLFsicGxuIiwvXltcdFxuXHIgXHhBMF0rLyxudWxsLCJcdFxuXHIgXHUwMGEwIl0sWyJz
dHIiLC9eXCIoPzpbXlwiXFxdfFxcW1xzXFNdKSooPzpcInwkKS8sbnVsbCwnIiddXSxbWyJrd2Qi
LC9eKD86YmxvY2t8Y1thZF0rcnxjYXRjaHxjb25bZHNdfGRlZig/OmluZXx1bil8ZG98ZXF8ZXFs
fGVxdWFsfGVxdWFscHxldmFsLXdoZW58ZmxldHxmb3JtYXR8Z298aWZ8bGFiZWxzfGxhbWJkYXxs
ZXR8bG9hZC10aW1lLXZhbHVlfGxvY2FsbHl8bWFjcm9sZXR8bXVsdGlwbGUtdmFsdWUtY2FsbHxu
aWx8cHJvZ258cHJvZ3Z8cXVvdGV8cmVxdWlyZXxyZXR1cm4tZnJvbXxzZXRxfHN5bWJvbC1tYWNy
b2xldHx0fHRhZ2JvZHl8dGhlfHRocm93fHVud2luZClcYi8sCm51bGxdLFsibGl0IiwvXlsrXC1d
Pyg/OjB4WzAtOWEtZl0rfFxkK1wvXGQrfCg/OlwuXGQrfFxkKyg/OlwuXGQqKT8pKD86W2VkXVsr
XC1dP1xkKyk/KS9pXSxbImxpdCIsL15cJyg/Oi0qKD86XHd8XFxbXHgyMS1ceDdlXSkoPzpbXHct
XSp8XFxbXHgyMS1ceDdlXSlbPSE/XT8pPy9dLFsicGxuIiwvXi0qKD86W2Etel9dfFxcW1x4MjEt
XHg3ZV0pKD86W1x3LV0qfFxcW1x4MjEtXHg3ZV0pWz0hP10/L2ldLFsicHVuIiwvXlteXHdcdFxu
XHIgXHhBMCgpXCJcXFwnO10rL11dKSxbImNsIiwiZWwiLCJsaXNwIiwic2NtIl0p

@@ js/lang-lua.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5cciBceEEwXSsvLG51bGwsIlx0XG5cciBcdTAwYTAiXSxbInN0ciIsL14oPzpcIig/OlteXCJc
XF18XFxbXHNcU10pKig/OlwifCQpfFwnKD86W15cJ1xcXXxcXFtcc1xTXSkqKD86XCd8JCkpLyxu
dWxsLCJcIiciXV0sW1siY29tIiwvXi0tKD86XFsoPSopXFtbXHNcU10qPyg/OlxdXDFcXXwkKXxb
XlxyXG5dKikvXSxbInN0ciIsL15cWyg9KilcW1tcc1xTXSo/KD86XF1cMVxdfCQpL10sWyJrd2Qi
LC9eKD86YW5kfGJyZWFrfGRvfGVsc2V8ZWxzZWlmfGVuZHxmYWxzZXxmb3J8ZnVuY3Rpb258aWZ8
aW58bG9jYWx8bmlsfG5vdHxvcnxyZXBlYXR8cmV0dXJufHRoZW58dHJ1ZXx1bnRpbHx3aGlsZSlc
Yi8sbnVsbF0sWyJsaXQiLC9eWystXT8oPzoweFtcZGEtZl0rfCg/Oig/OlwuXGQrfFxkKyg/Olwu
XGQqKT8pKD86ZVsrXC1dP1xkKyk/KSkvaV0sClsicGxuIiwvXlthLXpfXVx3Ki9pXSxbInB1biIs
L15bXlx3XHRcblxyIFx4QTBdW15cd1x0XG5cciBceEEwXCJcJ1wtXCs9XSovXV0pLFsibHVhIl0p

@@ js/lang-ml.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5cciBceEEwXSsvLG51bGwsIlx0XG5cciBcdTAwYTAiXSxbImNvbSIsL14jKD86aWZbXHRcblxy
IFx4QTBdKyg/OlthLXpfJF1bXHdcJ10qfGBgW15cclxuXHRgXSooPzpgYHwkKSl8ZWxzZXxlbmRp
ZnxsaWdodCkvaSxudWxsLCIjIl0sWyJzdHIiLC9eKD86XCIoPzpbXlwiXFxdfFxcW1xzXFNdKSoo
PzpcInwkKXxcJyg/OlteXCdcXF18XFxbXHNcU10pKig/OlwnfCQpKS8sbnVsbCwiXCInIl1dLFtb
ImNvbSIsL14oPzpcL1wvW15cclxuXSp8XChcKltcc1xTXSo/XCpcKSkvXSxbImt3ZCIsL14oPzph
YnN0cmFjdHxhbmR8YXN8YXNzZXJ0fGJlZ2lufGNsYXNzfGRlZmF1bHR8ZGVsZWdhdGV8ZG98ZG9u
ZXxkb3duY2FzdHxkb3dudG98ZWxpZnxlbHNlfGVuZHxleGNlcHRpb258ZXh0ZXJufGZhbHNlfGZp
bmFsbHl8Zm9yfGZ1bnxmdW5jdGlvbnxpZnxpbnxpbmhlcml0fGlubGluZXxpbnRlcmZhY2V8aW50
ZXJuYWx8bGF6eXxsZXR8bWF0Y2h8bWVtYmVyfG1vZHVsZXxtdXRhYmxlfG5hbWVzcGFjZXxuZXd8
bnVsbHxvZnxvcGVufG9yfG92ZXJyaWRlfHByaXZhdGV8cHVibGljfHJlY3xyZXR1cm58c3RhdGlj
fHN0cnVjdHx0aGVufHRvfHRydWV8dHJ5fHR5cGV8dXBjYXN0fHVzZXx2YWx8dm9pZHx3aGVufHdo
aWxlfHdpdGh8eWllbGR8YXNyfGxhbmR8bG9yfGxzbHxsc3J8bHhvcnxtb2R8c2lnfGF0b21pY3xi
cmVha3xjaGVja2VkfGNvbXBvbmVudHxjb25zdHxjb25zdHJhaW50fGNvbnN0cnVjdG9yfGNvbnRp
bnVlfGVhZ2VyfGV2ZW50fGV4dGVybmFsfGZpeGVkfGZ1bmN0b3J8Z2xvYmFsfGluY2x1ZGV8bWV0
aG9kfG1peGlufG9iamVjdHxwYXJhbGxlbHxwcm9jZXNzfHByb3RlY3RlZHxwdXJlfHNlYWxlZHx0
cmFpdHx2aXJ0dWFsfHZvbGF0aWxlKVxiL10sClsibGl0IiwvXlsrXC1dPyg/OjB4W1xkYS1mXSt8
KD86KD86XC5cZCt8XGQrKD86XC5cZCopPykoPzplWytcLV0/XGQrKT8pKS9pXSxbInBsbiIsL14o
PzpbYS16X11cdypbIT8jXT98YGBbXlxyXG5cdGBdKig/OmBgfCQpKS9pXSxbInB1biIsL15bXlx0
XG5cciBceEEwXCJcJ1x3XSsvXV0pLFsiZnMiLCJtbCJdKQ==

@@ js/lang-proto.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5zb3VyY2VEZWNvcmF0b3Ioe2tleXdvcmRzOiJib29s
IGJ5dGVzIGRlZmF1bHQgZG91YmxlIGVudW0gZXh0ZW5kIGV4dGVuc2lvbnMgZmFsc2UgZml4ZWQz
MiBmaXhlZDY0IGZsb2F0IGdyb3VwIGltcG9ydCBpbnQzMiBpbnQ2NCBtYXggbWVzc2FnZSBvcHRp
b24gb3B0aW9uYWwgcGFja2FnZSByZXBlYXRlZCByZXF1aXJlZCByZXR1cm5zIHJwYyBzZXJ2aWNl
IHNmaXhlZDMyIHNmaXhlZDY0IHNpbnQzMiBzaW50NjQgc3RyaW5nIHN5bnRheCB0byB0cnVlIHVp
bnQzMiB1aW50NjQiLGNTdHlsZUNvbW1lbnRzOnRydWV9KSxbInByb3RvIl0p

@@ js/lang-scala.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5cciBceEEwXSsvLG51bGwsIlx0XG5cciBcdTAwYTAiXSxbInN0ciIsL14oPzoiKD86KD86IiIo
PzoiIj8oPyEiKXxbXlxcIl18XFwuKSoiezAsM30pfCg/OlteIlxyXG5cXF18XFwuKSoiPykpLyxu
dWxsLCciJ10sWyJsaXQiLC9eYCg/OlteXHJcblxcYF18XFwuKSpgPy8sbnVsbCwiYCJdLFsicHVu
IiwvXlshIyUmKCkqKyxcLTo7PD0+P0BcW1xcXF1ee3x9fl0rLyxudWxsLCIhIyUmKCkqKywtOjs8
PT4/QFtcXF1ee3x9fiJdXSxbWyJzdHIiLC9eJyg/OlteXHJcblxcJ118XFwoPzonfFteXHJcbidd
KykpJy9dLFsibGl0IiwvXidbYS16QS1aXyRdW1x3JF0qKD8hWyckXHddKS9dLFsia3dkIiwvXig/
OmFic3RyYWN0fGNhc2V8Y2F0Y2h8Y2xhc3N8ZGVmfGRvfGVsc2V8ZXh0ZW5kc3xmaW5hbHxmaW5h
bGx5fGZvcnxmb3JTb21lfGlmfGltcGxpY2l0fGltcG9ydHxsYXp5fG1hdGNofG5ld3xvYmplY3R8
b3ZlcnJpZGV8cGFja2FnZXxwcml2YXRlfHByb3RlY3RlZHxyZXF1aXJlc3xyZXR1cm58c2VhbGVk
fHN1cGVyfHRocm93fHRyYWl0fHRyeXx0eXBlfHZhbHx2YXJ8d2hpbGV8d2l0aHx5aWVsZClcYi9d
LApbImxpdCIsL14oPzp0cnVlfGZhbHNlfG51bGx8dGhpcylcYi9dLFsibGl0IiwvXig/Oig/OjAo
PzpbMC03XSt8WFswLTlBLUZdKykpTD98KD86KD86MHxbMS05XVswLTldKikoPzooPzpcLlswLTld
Kyk/KD86RVsrXC1dP1swLTldKyk/Rj98TD8pKXxcXC5bMC05XSsoPzpFWytcLV0/WzAtOV0rKT9G
PykvaV0sWyJ0eXAiLC9eWyRfXSpbQS1aXVtfJEEtWjAtOV0qW2Etel1bXHckXSovXSxbInBsbiIs
L15bJGEtekEtWl9dW1x3JF0qL10sWyJjb20iLC9eXC8oPzpcLy4qfFwqKD86XC98XCoqW14qL10p
Kig/OlwqK1wvPyk/KS9dLFsicHVuIiwvXig/OlwuK3xcLykvXV0pLFsic2NhbGEiXSk=

@@ js/lang-sql.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5cciBceEEwXSsvLG51bGwsIlx0XG5cciBcdTAwYTAiXSxbInN0ciIsL14oPzoiKD86W15cIlxc
XXxcXC4pKiJ8Jyg/OlteXCdcXF18XFwuKSonKS8sbnVsbCwiXCInIl1dLFtbImNvbSIsL14oPzot
LVteXHJcbl0qfFwvXCpbXHNcU10qPyg/OlwqXC98JCkpL10sWyJrd2QiLC9eKD86QUREfEFMTHxB
TFRFUnxBTkR8QU5ZfEFTfEFTQ3xBVVRIT1JJWkFUSU9OfEJBQ0tVUHxCRUdJTnxCRVRXRUVOfEJS
RUFLfEJST1dTRXxCVUxLfEJZfENBU0NBREV8Q0FTRXxDSEVDS3xDSEVDS1BPSU5UfENMT1NFfENM
VVNURVJFRHxDT0FMRVNDRXxDT0xMQVRFfENPTFVNTnxDT01NSVR8Q09NUFVURXxDT05TVFJBSU5U
fENPTlRBSU5TfENPTlRBSU5TVEFCTEV8Q09OVElOVUV8Q09OVkVSVHxDUkVBVEV8Q1JPU1N8Q1VS
UkVOVHxDVVJSRU5UX0RBVEV8Q1VSUkVOVF9USU1FfENVUlJFTlRfVElNRVNUQU1QfENVUlJFTlRf
VVNFUnxDVVJTT1J8REFUQUJBU0V8REJDQ3xERUFMTE9DQVRFfERFQ0xBUkV8REVGQVVMVHxERUxF
VEV8REVOWXxERVNDfERJU0t8RElTVElOQ1R8RElTVFJJQlVURUR8RE9VQkxFfERST1B8RFVNTVl8
RFVNUHxFTFNFfEVORHxFUlJMVkx8RVNDQVBFfEVYQ0VQVHxFWEVDfEVYRUNVVEV8RVhJU1RTfEVY
SVR8RkVUQ0h8RklMRXxGSUxMRkFDVE9SfEZPUnxGT1JFSUdOfEZSRUVURVhUfEZSRUVURVhUVEFC
TEV8RlJPTXxGVUxMfEZVTkNUSU9OfEdPVE98R1JBTlR8R1JPVVB8SEFWSU5HfEhPTERMT0NLfElE
RU5USVRZfElERU5USVRZQ09MfElERU5USVRZX0lOU0VSVHxJRnxJTnxJTkRFWHxJTk5FUnxJTlNF
UlR8SU5URVJTRUNUfElOVE98SVN8Sk9JTnxLRVl8S0lMTHxMRUZUfExJS0V8TElORU5PfExPQUR8
TkFUSU9OQUx8Tk9DSEVDS3xOT05DTFVTVEVSRUR8Tk9UfE5VTEx8TlVMTElGfE9GfE9GRnxPRkZT
RVRTfE9OfE9QRU58T1BFTkRBVEFTT1VSQ0V8T1BFTlFVRVJZfE9QRU5ST1dTRVR8T1BFTlhNTHxP
UFRJT058T1J8T1JERVJ8T1VURVJ8T1ZFUnxQRVJDRU5UfFBMQU58UFJFQ0lTSU9OfFBSSU1BUll8
UFJJTlR8UFJPQ3xQUk9DRURVUkV8UFVCTElDfFJBSVNFUlJPUnxSRUFEfFJFQURURVhUfFJFQ09O
RklHVVJFfFJFRkVSRU5DRVN8UkVQTElDQVRJT058UkVTVE9SRXxSRVNUUklDVHxSRVRVUk58UkVW
T0tFfFJJR0hUfFJPTExCQUNLfFJPV0NPVU5UfFJPV0dVSURDT0x8UlVMRXxTQVZFfFNDSEVNQXxT
RUxFQ1R8U0VTU0lPTl9VU0VSfFNFVHxTRVRVU0VSfFNIVVRET1dOfFNPTUV8U1RBVElTVElDU3xT
WVNURU1fVVNFUnxUQUJMRXxURVhUU0laRXxUSEVOfFRPfFRPUHxUUkFOfFRSQU5TQUNUSU9OfFRS
SUdHRVJ8VFJVTkNBVEV8VFNFUVVBTHxVTklPTnxVTklRVUV8VVBEQVRFfFVQREFURVRFWFR8VVNF
fFVTRVJ8VkFMVUVTfFZBUllJTkd8VklFV3xXQUlURk9SfFdIRU58V0hFUkV8V0hJTEV8V0lUSHxX
UklURVRFWFQpKD89W15cdy1dfCQpL2ksCm51bGxdLFsibGl0IiwvXlsrLV0/KD86MHhbXGRhLWZd
K3woPzooPzpcLlxkK3xcZCsoPzpcLlxkKik/KSg/OmVbK1wtXT9cZCspPykpL2ldLFsicGxuIiwv
XlthLXpfXVtcdy1dKi9pXSxbInB1biIsL15bXlx3XHRcblxyIFx4QTBcIlwnXVteXHdcdFxuXHIg
XHhBMCtcLVwiXCddKi9dXSksWyJzcWwiXSk=

@@ js/lang-vb.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5cciBceEEwXHUyMDI4XHUyMDI5XSsvLG51bGwsIlx0XG5cciBcdTAwYTBcdTIwMjhcdTIwMjki
XSxbInN0ciIsL14oPzpbXCJcdTIwMUNcdTIwMURdKD86W15cIlx1MjAxQ1x1MjAxRF18W1wiXHUy
MDFDXHUyMDFEXXsyfSkoPzpbXCJcdTIwMUNcdTIwMURdY3wkKXxbXCJcdTIwMUNcdTIwMURdKD86
W15cIlx1MjAxQ1x1MjAxRF18W1wiXHUyMDFDXHUyMDFEXXsyfSkqKD86W1wiXHUyMDFDXHUyMDFE
XXwkKSkvaSxudWxsLCciXHUyMDFjXHUyMDFkJ10sWyJjb20iLC9eW1wnXHUyMDE4XHUyMDE5XVte
XHJcblx1MjAyOFx1MjAyOV0qLyxudWxsLCInXHUyMDE4XHUyMDE5Il1dLFtbImt3ZCIsL14oPzpB
ZGRIYW5kbGVyfEFkZHJlc3NPZnxBbGlhc3xBbmR8QW5kQWxzb3xBbnNpfEFzfEFzc2VtYmx5fEF1
dG98Qm9vbGVhbnxCeVJlZnxCeXRlfEJ5VmFsfENhbGx8Q2FzZXxDYXRjaHxDQm9vbHxDQnl0ZXxD
Q2hhcnxDRGF0ZXxDRGJsfENEZWN8Q2hhcnxDSW50fENsYXNzfENMbmd8Q09ianxDb25zdHxDU2hv
cnR8Q1NuZ3xDU3RyfENUeXBlfERhdGV8RGVjaW1hbHxEZWNsYXJlfERlZmF1bHR8RGVsZWdhdGV8
RGltfERpcmVjdENhc3R8RG98RG91YmxlfEVhY2h8RWxzZXxFbHNlSWZ8RW5kfEVuZElmfEVudW18
RXJhc2V8RXJyb3J8RXZlbnR8RXhpdHxGaW5hbGx5fEZvcnxGcmllbmR8RnVuY3Rpb258R2V0fEdl
dFR5cGV8R29TdWJ8R29Ub3xIYW5kbGVzfElmfEltcGxlbWVudHN8SW1wb3J0c3xJbnxJbmhlcml0
c3xJbnRlZ2VyfEludGVyZmFjZXxJc3xMZXR8TGlifExpa2V8TG9uZ3xMb29wfE1lfE1vZHxNb2R1
bGV8TXVzdEluaGVyaXR8TXVzdE92ZXJyaWRlfE15QmFzZXxNeUNsYXNzfE5hbWVzcGFjZXxOZXd8
TmV4dHxOb3R8Tm90SW5oZXJpdGFibGV8Tm90T3ZlcnJpZGFibGV8T2JqZWN0fE9ufE9wdGlvbnxP
cHRpb25hbHxPcnxPckVsc2V8T3ZlcmxvYWRzfE92ZXJyaWRhYmxlfE92ZXJyaWRlc3xQYXJhbUFy
cmF5fFByZXNlcnZlfFByaXZhdGV8UHJvcGVydHl8UHJvdGVjdGVkfFB1YmxpY3xSYWlzZUV2ZW50
fFJlYWRPbmx5fFJlRGltfFJlbW92ZUhhbmRsZXJ8UmVzdW1lfFJldHVybnxTZWxlY3R8U2V0fFNo
YWRvd3N8U2hhcmVkfFNob3J0fFNpbmdsZXxTdGF0aWN8U3RlcHxTdG9wfFN0cmluZ3xTdHJ1Y3R1
cmV8U3VifFN5bmNMb2NrfFRoZW58VGhyb3d8VG98VHJ5fFR5cGVPZnxVbmljb2RlfFVudGlsfFZh
cmlhbnR8V2VuZHxXaGVufFdoaWxlfFdpdGh8V2l0aEV2ZW50c3xXcml0ZU9ubHl8WG9yfEVuZElm
fEdvU3VifExldHxWYXJpYW50fFdlbmQpXGIvaSwKbnVsbF0sWyJjb20iLC9eUkVNW15cclxuXHUy
MDI4XHUyMDI5XSovaV0sWyJsaXQiLC9eKD86VHJ1ZVxifEZhbHNlXGJ8Tm90aGluZ1xifFxkKyg/
OkVbK1wtXT9cZCtbRlJEXT98W0ZSRFNJTF0pP3woPzomSFswLTlBLUZdK3wmT1swLTddKylbU0lM
XT98XGQqXC5cZCsoPzpFWytcLV0/XGQrKT9bRlJEXT98I1xzKyg/OlxkK1tcLVwvXVxkK1tcLVwv
XVxkKyg/OlxzK1xkKzpcZCsoPzo6XGQrKT8oXHMqKD86QU18UE0pKT8pP3xcZCs6XGQrKD86Olxk
Kyk/KFxzKig/OkFNfFBNKSk/KVxzKyMpL2ldLFsicGxuIiwvXig/Oig/OlthLXpdfF9cdylcdyp8
XFsoPzpbYS16XXxfXHcpXHcqXF0pL2ldLFsicHVuIiwvXlteXHdcdFxuXHIgXCJcJ1xbXF1ceEEw
XHUyMDE4XHUyMDE5XHUyMDFDXHUyMDFEXHUyMDI4XHUyMDI5XSsvXSxbInB1biIsL14oPzpcW3xc
XSkvXV0pLFsidmIiLCJ2YnMiXSk=

@@ js/lang-vhdl.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
XG5cciBceEEwXSsvLG51bGwsIlx0XG5cciBcdTAwYTAiXV0sW1sic3RyIiwvXig/OltCT1hdPyIo
PzpbXlwiXXwiIikqInwnLicpL2ldLFsiY29tIiwvXi0tW15cclxuXSovXSxbImt3ZCIsL14oPzph
YnN8YWNjZXNzfGFmdGVyfGFsaWFzfGFsbHxhbmR8YXJjaGl0ZWN0dXJlfGFycmF5fGFzc2VydHxh
dHRyaWJ1dGV8YmVnaW58YmxvY2t8Ym9keXxidWZmZXJ8YnVzfGNhc2V8Y29tcG9uZW50fGNvbmZp
Z3VyYXRpb258Y29uc3RhbnR8ZGlzY29ubmVjdHxkb3dudG98ZWxzZXxlbHNpZnxlbmR8ZW50aXR5
fGV4aXR8ZmlsZXxmb3J8ZnVuY3Rpb258Z2VuZXJhdGV8Z2VuZXJpY3xncm91cHxndWFyZGVkfGlm
fGltcHVyZXxpbnxpbmVydGlhbHxpbm91dHxpc3xsYWJlbHxsaWJyYXJ5fGxpbmthZ2V8bGl0ZXJh
bHxsb29wfG1hcHxtb2R8bmFuZHxuZXd8bmV4dHxub3J8bm90fG51bGx8b2Z8b258b3Blbnxvcnxv
dGhlcnN8b3V0fHBhY2thZ2V8cG9ydHxwb3N0cG9uZWR8cHJvY2VkdXJlfHByb2Nlc3N8cHVyZXxy
YW5nZXxyZWNvcmR8cmVnaXN0ZXJ8cmVqZWN0fHJlbXxyZXBvcnR8cmV0dXJufHJvbHxyb3J8c2Vs
ZWN0fHNldmVyaXR5fHNoYXJlZHxzaWduYWx8c2xhfHNsbHxzcmF8c3JsfHN1YnR5cGV8dGhlbnx0
b3x0cmFuc3BvcnR8dHlwZXx1bmFmZmVjdGVkfHVuaXRzfHVudGlsfHVzZXx2YXJpYWJsZXx3YWl0
fHdoZW58d2hpbGV8d2l0aHx4bm9yfHhvcikoPz1bXlx3LV18JCkvaSwKbnVsbF0sWyJ0eXAiLC9e
KD86Yml0fGJpdF92ZWN0b3J8Y2hhcmFjdGVyfGJvb2xlYW58aW50ZWdlcnxyZWFsfHRpbWV8c3Ry
aW5nfHNldmVyaXR5X2xldmVsfHBvc2l0aXZlfG5hdHVyYWx8c2lnbmVkfHVuc2lnbmVkfGxpbmV8
dGV4dHxzdGRfdT9sb2dpYyg/Ol92ZWN0b3IpPykoPz1bXlx3LV18JCkvaSxudWxsXSxbInR5cCIs
L15cJyg/OkFDVElWRXxBU0NFTkRJTkd8QkFTRXxERUxBWUVEfERSSVZJTkd8RFJJVklOR19WQUxV
RXxFVkVOVHxISUdIfElNQUdFfElOU1RBTkNFX05BTUV8TEFTVF9BQ1RJVkV8TEFTVF9FVkVOVHxM
QVNUX1ZBTFVFfExFRlR8TEVGVE9GfExFTkdUSHxMT1d8UEFUSF9OQU1FfFBPU3xQUkVEfFFVSUVU
fFJBTkdFfFJFVkVSU0VfUkFOR0V8UklHSFR8UklHSFRPRnxTSU1QTEVfTkFNRXxTVEFCTEV8U1VD
Q3xUUkFOU0FDVElPTnxWQUx8VkFMVUUpKD89W15cdy1dfCQpL2ksbnVsbF0sWyJsaXQiLC9eXGQr
KD86X1xkKykqKD86I1tcd1xcLl0rIyg/OlsrXC1dP1xkKyg/Ol9cZCspKik/fCg/OlwuXGQrKD86
X1xkKykqKT8oPzpFWytcLV0/XGQrKD86X1xkKykqKT8pL2ldLApbInBsbiIsL14oPzpbYS16XVx3
KnxcXFteXFxdKlxcKS9pXSxbInB1biIsL15bXlx3XHRcblxyIFx4QTBcIlwnXVteXHdcdFxuXHIg
XHhBMFwtXCJcJ10qL11dKSxbInZoZGwiLCJ2aGQiXSk=

@@ js/lang-wiki.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwbG4iLC9eW1x0
IFx4QTBhLWdpLXowLTldKy8sbnVsbCwiXHQgXHUwMGEwYWJjZGVmZ2lqa2xtbm9wcXJzdHV2d3h5
ejAxMjM0NTY3ODkiXSxbInB1biIsL15bPSp+XF5cW1xdXSsvLG51bGwsIj0qfl5bXSJdXSxbWyJs
YW5nLXdpa2kubWV0YSIsLyg/Ol5efFxyXG4/fFxuKSgjW2Etel0rKVxiL10sWyJsaXQiLC9eKD86
W0EtWl1bYS16XVthLXowLTldK1tBLVpdW2Etel1bYS16QS1aMC05XSspXGIvXSxbImxhbmctIiwv
Xlx7XHtceyhbXHNcU10rPylcfVx9XH0vXSxbImxhbmctIiwvXmAoW15cclxuYF0rKWAvXSxbInN0
ciIsL15odHRwcz86XC9cL1teXC8/I1xzXSooPzpcL1tePyNcc10qKT8oPzpcP1teI1xzXSopPyg/
OiNcUyopPy9pXSxbInBsbiIsL14oPzpcclxufFtcc1xTXSlbXiM9Kn5eQS1aaFx7YFxbXHJcbl0q
L11dKSxbIndpa2kiXSk7ClBSLnJlZ2lzdGVyTGFuZ0hhbmRsZXIoUFIuY3JlYXRlU2ltcGxlTGV4
ZXIoW1sia3dkIiwvXiNbYS16XSsvaSxudWxsLCIjIl1dLFtdKSxbIndpa2kubWV0YSJdKQ==

@@ js/lang-yaml.js (base64)
UFIucmVnaXN0ZXJMYW5nSGFuZGxlcihQUi5jcmVhdGVTaW1wbGVMZXhlcihbWyJwdW4iLC9eWzp8
Pj9dKy8sbnVsbCwiOnw+PyJdLFsiZGVjIiwvXiUoPzpZQU1MfFRBRylbXiNcclxuXSsvLG51bGws
IiUiXSxbInR5cCIsL15bJl1cUysvLG51bGwsIiYiXSxbInR5cCIsL14hXFMqLyxudWxsLCIhIl0s
WyJzdHIiLC9eIig/OlteXFwiXXxcXC4pKig/OiJ8JCkvLG51bGwsJyInXSxbInN0ciIsL14nKD86
W14nXXwnJykqKD86J3wkKS8sbnVsbCwiJyJdLFsiY29tIiwvXiNbXlxyXG5dKi8sbnVsbCwiIyJd
LFsicGxuIiwvXlxzKy8sbnVsbCwiIFx0XHJcbiJdXSxbWyJkZWMiLC9eKD86LS0tfFwuXC5cLiko
PzpbXHJcbl18JCkvXSxbInB1biIsL14tL10sWyJrd2QiLC9eXHcrOlsgXHJcbl0vXSxbInBsbiIs
L15cdysvXV0pLApbInlhbWwiLCJ5bWwiXSk=

@@ js/prettify.js (base64)
d2luZG93LlBSX1NIT1VMRF9VU0VfQ09OVElOVUFUSU9OPXRydWU7d2luZG93LlBSX1RBQl9XSURU
SD04O3dpbmRvdy5QUl9ub3JtYWxpemVkSHRtbD13aW5kb3cuUFI9d2luZG93LnByZXR0eVByaW50
T25lPXdpbmRvdy5wcmV0dHlQcmludD12b2lkIDA7d2luZG93Ll9wcl9pc0lFNj1mdW5jdGlvbigp
e3ZhciB5PW5hdmlnYXRvciYmbmF2aWdhdG9yLnVzZXJBZ2VudCYmbmF2aWdhdG9yLnVzZXJBZ2Vu
dC5tYXRjaCgvXGJNU0lFIChbNjc4XSlcLi8pO3k9eT8reVsxXTpmYWxzZTt3aW5kb3cuX3ByX2lz
SUU2PWZ1bmN0aW9uKCl7cmV0dXJuIHl9O3JldHVybiB5fTsKKGZ1bmN0aW9uKCl7ZnVuY3Rpb24g
eShiKXtyZXR1cm4gYi5yZXBsYWNlKEwsIiZhbXA7IikucmVwbGFjZShNLCImbHQ7IikucmVwbGFj
ZShOLCImZ3Q7Iil9ZnVuY3Rpb24gSChiLGYsaSl7c3dpdGNoKGIubm9kZVR5cGUpe2Nhc2UgMTp2
YXIgbz1iLnRhZ05hbWUudG9Mb3dlckNhc2UoKTtmLnB1c2goIjwiLG8pO3ZhciBsPWIuYXR0cmli
dXRlcyxuPWwubGVuZ3RoO2lmKG4pe2lmKGkpe2Zvcih2YXIgcj1bXSxqPW47LS1qPj0wOylyW2pd
PWxbal07ci5zb3J0KGZ1bmN0aW9uKHEsbSl7cmV0dXJuIHEubmFtZTxtLm5hbWU/LTE6cS5uYW1l
PT09bS5uYW1lPzA6MX0pO2w9cn1mb3Ioaj0wO2o8bjsrK2ope3I9bFtqXTtyLnNwZWNpZmllZCYm
Zi5wdXNoKCIgIixyLm5hbWUudG9Mb3dlckNhc2UoKSwnPSInLHIudmFsdWUucmVwbGFjZShMLCIm
YW1wOyIpLnJlcGxhY2UoTSwiJmx0OyIpLnJlcGxhY2UoTiwiJmd0OyIpLnJlcGxhY2UoWCwiJnF1
b3Q7IiksJyInKX19Zi5wdXNoKCI+Iik7CmZvcihsPWIuZmlyc3RDaGlsZDtsO2w9bC5uZXh0U2li
bGluZylIKGwsZixpKTtpZihiLmZpcnN0Q2hpbGR8fCEvXig/OmJyfGxpbmt8aW1nKSQvLnRlc3Qo
bykpZi5wdXNoKCI8LyIsbywiPiIpO2JyZWFrO2Nhc2UgMzpjYXNlIDQ6Zi5wdXNoKHkoYi5ub2Rl
VmFsdWUpKTticmVha319ZnVuY3Rpb24gTyhiKXtmdW5jdGlvbiBmKGMpe2lmKGMuY2hhckF0KDAp
IT09IlxcIilyZXR1cm4gYy5jaGFyQ29kZUF0KDApO3N3aXRjaChjLmNoYXJBdCgxKSl7Y2FzZSAi
YiI6cmV0dXJuIDg7Y2FzZSAidCI6cmV0dXJuIDk7Y2FzZSAibiI6cmV0dXJuIDEwO2Nhc2UgInYi
OnJldHVybiAxMTtjYXNlICJmIjpyZXR1cm4gMTI7Y2FzZSAiciI6cmV0dXJuIDEzO2Nhc2UgInUi
OmNhc2UgIngiOnJldHVybiBwYXJzZUludChjLnN1YnN0cmluZygyKSwxNil8fGMuY2hhckNvZGVB
dCgxKTtjYXNlICIwIjpjYXNlICIxIjpjYXNlICIyIjpjYXNlICIzIjpjYXNlICI0IjpjYXNlICI1
IjpjYXNlICI2IjpjYXNlICI3IjpyZXR1cm4gcGFyc2VJbnQoYy5zdWJzdHJpbmcoMSksCjgpO2Rl
ZmF1bHQ6cmV0dXJuIGMuY2hhckNvZGVBdCgxKX19ZnVuY3Rpb24gaShjKXtpZihjPDMyKXJldHVy
bihjPDE2PyJcXHgwIjoiXFx4IikrYy50b1N0cmluZygxNik7Yz1TdHJpbmcuZnJvbUNoYXJDb2Rl
KGMpO2lmKGM9PT0iXFwifHxjPT09Ii0ifHxjPT09IlsifHxjPT09Il0iKWM9IlxcIitjO3JldHVy
biBjfWZ1bmN0aW9uIG8oYyl7dmFyIGQ9Yy5zdWJzdHJpbmcoMSxjLmxlbmd0aC0xKS5tYXRjaChS
ZWdFeHAoIlxcXFx1WzAtOUEtRmEtZl17NH18XFxcXHhbMC05QS1GYS1mXXsyfXxcXFxcWzAtM11b
MC03XXswLDJ9fFxcXFxbMC03XXsxLDJ9fFxcXFxbXFxzXFxTXXwtfFteLVxcXFxdIiwiZyIpKTtj
PVtdO2Zvcih2YXIgYT1bXSxrPWRbMF09PT0iXiIsZT1rPzE6MCxoPWQubGVuZ3RoO2U8aDsrK2Up
e3ZhciBnPWRbZV07c3dpdGNoKGcpe2Nhc2UgIlxcQiI6Y2FzZSAiXFxiIjpjYXNlICJcXEQiOmNh
c2UgIlxcZCI6Y2FzZSAiXFxTIjpjYXNlICJcXHMiOmNhc2UgIlxcVyI6Y2FzZSAiXFx3IjpjLnB1
c2goZyk7CmNvbnRpbnVlfWc9ZihnKTt2YXIgcztpZihlKzI8aCYmIi0iPT09ZFtlKzFdKXtzPWYo
ZFtlKzJdKTtlKz0yfWVsc2Ugcz1nO2EucHVzaChbZyxzXSk7aWYoIShzPDY1fHxnPjEyMikpe3M8
NjV8fGc+OTB8fGEucHVzaChbTWF0aC5tYXgoNjUsZyl8MzIsTWF0aC5taW4ocyw5MCl8MzJdKTtz
PDk3fHxnPjEyMnx8YS5wdXNoKFtNYXRoLm1heCg5NyxnKSYtMzMsTWF0aC5taW4ocywxMjIpJi0z
M10pfX1hLnNvcnQoZnVuY3Rpb24odix3KXtyZXR1cm4gdlswXS13WzBdfHx3WzFdLXZbMV19KTtk
PVtdO2c9W05hTixOYU5dO2ZvcihlPTA7ZTxhLmxlbmd0aDsrK2Upe2g9YVtlXTtpZihoWzBdPD1n
WzFdKzEpZ1sxXT1NYXRoLm1heChnWzFdLGhbMV0pO2Vsc2UgZC5wdXNoKGc9aCl9YT1bIlsiXTtr
JiZhLnB1c2goIl4iKTthLnB1c2guYXBwbHkoYSxjKTtmb3IoZT0wO2U8ZC5sZW5ndGg7KytlKXto
PWRbZV07YS5wdXNoKGkoaFswXSkpO2lmKGhbMV0+aFswXSl7aFsxXSsxPmhbMF0mJmEucHVzaCgi
LSIpOwphLnB1c2goaShoWzFdKSl9fWEucHVzaCgiXSIpO3JldHVybiBhLmpvaW4oIiIpfWZ1bmN0
aW9uIGwoYyl7Zm9yKHZhciBkPWMuc291cmNlLm1hdGNoKFJlZ0V4cCgiKD86XFxbKD86W15cXHg1
Q1xceDVEXXxcXFxcW1xcc1xcU10pKlxcXXxcXFxcdVtBLUZhLWYwLTldezR9fFxcXFx4W0EtRmEt
ZjAtOV17Mn18XFxcXFswLTldK3xcXFxcW151eDAtOV18XFwoXFw/WzohPV18W1xcKFxcKVxcXl18
W15cXHg1QlxceDVDXFwoXFwpXFxeXSspIiwiZyIpKSxhPWQubGVuZ3RoLGs9W10sZT0wLGg9MDtl
PGE7KytlKXt2YXIgZz1kW2VdO2lmKGc9PT0iKCIpKytoO2Vsc2UgaWYoIlxcIj09PWcuY2hhckF0
KDApKWlmKChnPStnLnN1YnN0cmluZygxKSkmJmc8PWgpa1tnXT0tMX1mb3IoZT0xO2U8ay5sZW5n
dGg7KytlKWlmKC0xPT09a1tlXSlrW2VdPSsrbjtmb3IoaD1lPTA7ZTxhOysrZSl7Zz1kW2VdO2lm
KGc9PT0iKCIpeysraDtpZihrW2hdPT09dW5kZWZpbmVkKWRbZV09Iig/OiJ9ZWxzZSBpZigiXFwi
PT09CmcuY2hhckF0KDApKWlmKChnPStnLnN1YnN0cmluZygxKSkmJmc8PWgpZFtlXT0iXFwiK2tb
aF19Zm9yKGg9ZT0wO2U8YTsrK2UpaWYoIl4iPT09ZFtlXSYmIl4iIT09ZFtlKzFdKWRbZV09IiI7
aWYoYy5pZ25vcmVDYXNlJiZyKWZvcihlPTA7ZTxhOysrZSl7Zz1kW2VdO2M9Zy5jaGFyQXQoMCk7
aWYoZy5sZW5ndGg+PTImJmM9PT0iWyIpZFtlXT1vKGcpO2Vsc2UgaWYoYyE9PSJcXCIpZFtlXT1n
LnJlcGxhY2UoL1thLXpBLVpdL2csZnVuY3Rpb24ocyl7cz1zLmNoYXJDb2RlQXQoMCk7cmV0dXJu
IlsiK1N0cmluZy5mcm9tQ2hhckNvZGUocyYtMzMsc3wzMikrIl0ifSl9cmV0dXJuIGQuam9pbigi
Iil9Zm9yKHZhciBuPTAscj1mYWxzZSxqPWZhbHNlLHE9MCxtPWIubGVuZ3RoO3E8bTsrK3Epe3Zh
ciB0PWJbcV07aWYodC5pZ25vcmVDYXNlKWo9dHJ1ZTtlbHNlIGlmKC9bYS16XS9pLnRlc3QodC5z
b3VyY2UucmVwbGFjZSgvXFx1WzAtOWEtZl17NH18XFx4WzAtOWEtZl17Mn18XFxbXnV4XS9naSwK
IiIpKSl7cj10cnVlO2o9ZmFsc2U7YnJlYWt9fXZhciBwPVtdO3E9MDtmb3IobT1iLmxlbmd0aDtx
PG07KytxKXt0PWJbcV07aWYodC5nbG9iYWx8fHQubXVsdGlsaW5lKXRocm93IEVycm9yKCIiK3Qp
O3AucHVzaCgiKD86IitsKHQpKyIpIil9cmV0dXJuIFJlZ0V4cChwLmpvaW4oInwiKSxqPyJnaSI6
ImciKX1mdW5jdGlvbiBZKGIpe3ZhciBmPTA7cmV0dXJuIGZ1bmN0aW9uKGkpe2Zvcih2YXIgbz1u
dWxsLGw9MCxuPTAscj1pLmxlbmd0aDtuPHI7KytuKXN3aXRjaChpLmNoYXJBdChuKSl7Y2FzZSAi
XHQiOm98fChvPVtdKTtvLnB1c2goaS5zdWJzdHJpbmcobCxuKSk7bD1iLWYlYjtmb3IoZis9bDts
Pj0wO2wtPTE2KW8ucHVzaCgiICAgICAgICAgICAgICAgICIuc3Vic3RyaW5nKDAsbCkpO2w9bisx
O2JyZWFrO2Nhc2UgIlxuIjpmPTA7YnJlYWs7ZGVmYXVsdDorK2Z9aWYoIW8pcmV0dXJuIGk7by5w
dXNoKGkuc3Vic3RyaW5nKGwpKTtyZXR1cm4gby5qb2luKCIiKX19ZnVuY3Rpb24gSShiLApmLGks
byl7aWYoZil7Yj17c291cmNlOmYsYzpifTtpKGIpO28ucHVzaC5hcHBseShvLGIuZCl9fWZ1bmN0
aW9uIEIoYixmKXt2YXIgaT17fSxvOyhmdW5jdGlvbigpe2Zvcih2YXIgcj1iLmNvbmNhdChmKSxq
PVtdLHE9e30sbT0wLHQ9ci5sZW5ndGg7bTx0OysrbSl7dmFyIHA9clttXSxjPXBbM107aWYoYylm
b3IodmFyIGQ9Yy5sZW5ndGg7LS1kPj0wOylpW2MuY2hhckF0KGQpXT1wO3A9cFsxXTtjPSIiK3A7
aWYoIXEuaGFzT3duUHJvcGVydHkoYykpe2oucHVzaChwKTtxW2NdPW51bGx9fWoucHVzaCgvW1ww
LVx1ZmZmZl0vKTtvPU8oail9KSgpO3ZhciBsPWYubGVuZ3RoO2Z1bmN0aW9uIG4ocil7Zm9yKHZh
ciBqPXIuYyxxPVtqLHpdLG09MCx0PXIuc291cmNlLm1hdGNoKG8pfHxbXSxwPXt9LGM9MCxkPXQu
bGVuZ3RoO2M8ZDsrK2Mpe3ZhciBhPXRbY10saz1wW2FdLGU9dm9pZCAwLGg7aWYodHlwZW9mIGs9
PT0ic3RyaW5nIiloPWZhbHNlO2Vsc2V7dmFyIGc9aVthLmNoYXJBdCgwKV07CmlmKGcpe2U9YS5t
YXRjaChnWzFdKTtrPWdbMF19ZWxzZXtmb3IoaD0wO2g8bDsrK2gpe2c9ZltoXTtpZihlPWEubWF0
Y2goZ1sxXSkpe2s9Z1swXTticmVha319ZXx8KGs9eil9aWYoKGg9ay5sZW5ndGg+PTUmJiJsYW5n
LSI9PT1rLnN1YnN0cmluZygwLDUpKSYmIShlJiZ0eXBlb2YgZVsxXT09PSJzdHJpbmciKSl7aD1m
YWxzZTtrPVB9aHx8KHBbYV09ayl9Zz1tO20rPWEubGVuZ3RoO2lmKGgpe2g9ZVsxXTt2YXIgcz1h
LmluZGV4T2YoaCksdj1zK2gubGVuZ3RoO2lmKGVbMl0pe3Y9YS5sZW5ndGgtZVsyXS5sZW5ndGg7
cz12LWgubGVuZ3RofWs9ay5zdWJzdHJpbmcoNSk7SShqK2csYS5zdWJzdHJpbmcoMCxzKSxuLHEp
O0koaitnK3MsaCxRKGssaCkscSk7SShqK2crdixhLnN1YnN0cmluZyh2KSxuLHEpfWVsc2UgcS5w
dXNoKGorZyxrKX1yLmQ9cX1yZXR1cm4gbn1mdW5jdGlvbiB4KGIpe3ZhciBmPVtdLGk9W107aWYo
Yi50cmlwbGVRdW90ZWRTdHJpbmdzKWYucHVzaChbQSwvXig/OlwnXCdcJyg/OlteXCdcXF18XFxb
XHNcU118XCd7MSwyfSg/PVteXCddKSkqKD86XCdcJ1wnfCQpfFwiXCJcIig/OlteXCJcXF18XFxb
XHNcU118XCJ7MSwyfSg/PVteXCJdKSkqKD86XCJcIlwifCQpfFwnKD86W15cXFwnXXxcXFtcc1xT
XSkqKD86XCd8JCl8XCIoPzpbXlxcXCJdfFxcW1xzXFNdKSooPzpcInwkKSkvLApudWxsLCInXCIi
XSk7ZWxzZSBiLm11bHRpTGluZVN0cmluZ3M/Zi5wdXNoKFtBLC9eKD86XCcoPzpbXlxcXCddfFxc
W1xzXFNdKSooPzpcJ3wkKXxcIig/OlteXFxcIl18XFxbXHNcU10pKig/OlwifCQpfFxgKD86W15c
XFxgXXxcXFtcc1xTXSkqKD86XGB8JCkpLyxudWxsLCInXCJgIl0pOmYucHVzaChbQSwvXig/Olwn
KD86W15cXFwnXHJcbl18XFwuKSooPzpcJ3wkKXxcIig/OlteXFxcIlxyXG5dfFxcLikqKD86XCJ8
JCkpLyxudWxsLCJcIiciXSk7Yi52ZXJiYXRpbVN0cmluZ3MmJmkucHVzaChbQSwvXkBcIig/Olte
XCJdfFwiXCIpKig/OlwifCQpLyxudWxsXSk7aWYoYi5oYXNoQ29tbWVudHMpaWYoYi5jU3R5bGVD
b21tZW50cyl7Zi5wdXNoKFtDLC9eIyg/Oig/OmRlZmluZXxlbGlmfGVsc2V8ZW5kaWZ8ZXJyb3J8
aWZkZWZ8aW5jbHVkZXxpZm5kZWZ8bGluZXxwcmFnbWF8dW5kZWZ8d2FybmluZylcYnxbXlxyXG5d
KikvLG51bGwsIiMiXSk7aS5wdXNoKFtBLC9ePCg/Oig/Oig/OlwuXC5cLykqfFwvPykoPzpbXHct
XSsoPzpcL1tcdy1dKykrKT9bXHctXStcLmh8W2Etel1cdyopPi8sCm51bGxdKX1lbHNlIGYucHVz
aChbQywvXiNbXlxyXG5dKi8sbnVsbCwiIyJdKTtpZihiLmNTdHlsZUNvbW1lbnRzKXtpLnB1c2go
W0MsL15cL1wvW15cclxuXSovLG51bGxdKTtpLnB1c2goW0MsL15cL1wqW1xzXFNdKj8oPzpcKlwv
fCQpLyxudWxsXSl9Yi5yZWdleExpdGVyYWxzJiZpLnB1c2goWyJsYW5nLXJlZ2V4IixSZWdFeHAo
Il4iK1orIigvKD89W14vKl0pKD86W14vXFx4NUJcXHg1Q118XFx4NUNbXFxzXFxTXXxcXHg1Qig/
OlteXFx4NUNcXHg1RF18XFx4NUNbXFxzXFxTXSkqKD86XFx4NUR8JCkpKy8pIildKTtiPWIua2V5
d29yZHMucmVwbGFjZSgvXlxzK3xccyskL2csIiIpO2IubGVuZ3RoJiZpLnB1c2goW1IsUmVnRXhw
KCJeKD86IitiLnJlcGxhY2UoL1xzKy9nLCJ8IikrIilcXGIiKSxudWxsXSk7Zi5wdXNoKFt6LC9e
XHMrLyxudWxsLCIgXHJcblx0XHUwMGEwIl0pO2kucHVzaChbSiwvXkBbYS16XyRdW2Etel8kQDAt
OV0qL2ksbnVsbF0sW1MsL15AP1tBLVpdK1thLXpdW0EtWmEtel8kQDAtOV0qLywKbnVsbF0sW3os
L15bYS16XyRdW2Etel8kQDAtOV0qL2ksbnVsbF0sW0osL14oPzoweFthLWYwLTldK3woPzpcZCg/
Ol9cZCspKlxkKig/OlwuXGQqKT98XC5cZFwrKSg/OmVbK1wtXT9cZCspPylbYS16XSovaSxudWxs
LCIwMTIzNDU2Nzg5Il0sW0UsL14uW15cc1x3XC4kQFwnXCJcYFwvXCNdKi8sbnVsbF0pO3JldHVy
biBCKGYsaSl9ZnVuY3Rpb24gJChiKXtmdW5jdGlvbiBmKEQpe2lmKEQ+cil7aWYoaiYmaiE9PXEp
e24ucHVzaCgiPC9zcGFuPiIpO2o9bnVsbH1pZighaiYmcSl7aj1xO24ucHVzaCgnPHNwYW4gY2xh
c3M9IicsaiwnIj4nKX12YXIgVD15KHAoaS5zdWJzdHJpbmcocixEKSkpLnJlcGxhY2UoZT9kOmMs
IiQxJiMxNjA7Iik7ZT1rLnRlc3QoVCk7bi5wdXNoKFQucmVwbGFjZShhLHMpKTtyPUR9fXZhciBp
PWIuc291cmNlLG89Yi5nLGw9Yi5kLG49W10scj0wLGo9bnVsbCxxPW51bGwsbT0wLHQ9MCxwPVko
d2luZG93LlBSX1RBQl9XSURUSCksYz0vKFtcclxuIF0pIC9nLApkPS8oXnwgKSAvZ20sYT0vXHJc
bj98XG4vZyxrPS9bIFxyXG5dJC8sZT10cnVlLGg9d2luZG93Ll9wcl9pc0lFNigpO2g9aD9iLmIu
dGFnTmFtZT09PSJQUkUiP2g9PT02PyImIzE2MDtcclxuIjpoPT09Nz8iJiMxNjA7PGJyPlxyIjoi
JiMxNjA7XHIiOiImIzE2MDs8YnIgLz4iOiI8YnIgLz4iO3ZhciBnPWIuYi5jbGFzc05hbWUubWF0
Y2goL1xibGluZW51bXNcYig/OjooXGQrKSk/LykscztpZihnKXtmb3IodmFyIHY9W10sdz0wO3c8
MTA7Kyt3KXZbd109aCsnPC9saT48bGkgY2xhc3M9IkwnK3crJyI+Jzt2YXIgRj1nWzFdJiZnWzFd
Lmxlbmd0aD9nWzFdLTE6MDtuLnB1c2goJzxvbCBjbGFzcz0ibGluZW51bXMiPjxsaSBjbGFzcz0i
TCcsRiUxMCwnIicpO0YmJm4ucHVzaCgnIHZhbHVlPSInLEYrMSwnIicpO24ucHVzaCgiPiIpO3M9
ZnVuY3Rpb24oKXt2YXIgRD12WysrRiUxMF07cmV0dXJuIGo/Ijwvc3Bhbj4iK0QrJzxzcGFuIGNs
YXNzPSInK2orJyI+JzpEfX1lbHNlIHM9aDsKZm9yKDs7KWlmKG08by5sZW5ndGg/dDxsLmxlbmd0
aD9vW21dPD1sW3RdOnRydWU6ZmFsc2Upe2Yob1ttXSk7aWYoail7bi5wdXNoKCI8L3NwYW4+Iik7
aj1udWxsfW4ucHVzaChvW20rMV0pO20rPTJ9ZWxzZSBpZih0PGwubGVuZ3RoKXtmKGxbdF0pO3E9
bFt0KzFdO3QrPTJ9ZWxzZSBicmVhaztmKGkubGVuZ3RoKTtqJiZuLnB1c2goIjwvc3Bhbj4iKTtn
JiZuLnB1c2goIjwvbGk+PC9vbD4iKTtiLmE9bi5qb2luKCIiKX1mdW5jdGlvbiB1KGIsZil7Zm9y
KHZhciBpPWYubGVuZ3RoOy0taT49MDspe3ZhciBvPWZbaV07aWYoRy5oYXNPd25Qcm9wZXJ0eShv
KSkiY29uc29sZSJpbiB3aW5kb3cmJmNvbnNvbGUud2FybigiY2Fubm90IG92ZXJyaWRlIGxhbmd1
YWdlIGhhbmRsZXIgJXMiLG8pO2Vsc2UgR1tvXT1ifX1mdW5jdGlvbiBRKGIsZil7YiYmRy5oYXNP
d25Qcm9wZXJ0eShiKXx8KGI9L15ccyo8Ly50ZXN0KGYpPyJkZWZhdWx0LW1hcmt1cCI6ImRlZmF1
bHQtY29kZSIpO3JldHVybiBHW2JdfQpmdW5jdGlvbiBVKGIpe3ZhciBmPWIuZixpPWIuZTtiLmE9
Zjt0cnl7dmFyIG8sbD1mLm1hdGNoKGFhKTtmPVtdO3ZhciBuPTAscj1bXTtpZihsKWZvcih2YXIg
aj0wLHE9bC5sZW5ndGg7ajxxOysrail7dmFyIG09bFtqXTtpZihtLmxlbmd0aD4xJiZtLmNoYXJB
dCgwKT09PSI8Iil7aWYoIWJhLnRlc3QobSkpaWYoY2EudGVzdChtKSl7Zi5wdXNoKG0uc3Vic3Ry
aW5nKDksbS5sZW5ndGgtMykpO24rPW0ubGVuZ3RoLTEyfWVsc2UgaWYoZGEudGVzdChtKSl7Zi5w
dXNoKCJcbiIpOysrbn1lbHNlIGlmKG0uaW5kZXhPZihWKT49MCYmbS5yZXBsYWNlKC9ccyhcdysp
XHMqPVxzKig/OlwiKFteXCJdKilcInwnKFteXCddKiknfChcUyspKS9nLCcgJDE9IiQyJDMkNCIn
KS5tYXRjaCgvW2NDXVtsTF1bYUFdW3NTXVtzU109XCJbXlwiXSpcYm5vY29kZVxiLykpe3ZhciB0
PW0ubWF0Y2goVylbMl0scD0xLGM7Yz1qKzE7YTpmb3IoO2M8cTsrK2Mpe3ZhciBkPWxbY10ubWF0
Y2goVyk7aWYoZCYmCmRbMl09PT10KWlmKGRbMV09PT0iLyIpe2lmKC0tcD09PTApYnJlYWsgYX1l
bHNlKytwfWlmKGM8cSl7ci5wdXNoKG4sbC5zbGljZShqLGMrMSkuam9pbigiIikpO2o9Y31lbHNl
IHIucHVzaChuLG0pfWVsc2Ugci5wdXNoKG4sbSl9ZWxzZXt2YXIgYTtwPW07dmFyIGs9cC5pbmRl
eE9mKCImIik7aWYoazwwKWE9cDtlbHNle2ZvcigtLWs7KGs9cC5pbmRleE9mKCImIyIsaysxKSk+
PTA7KXt2YXIgZT1wLmluZGV4T2YoIjsiLGspO2lmKGU+PTApe3ZhciBoPXAuc3Vic3RyaW5nKGsr
MyxlKSxnPTEwO2lmKGgmJmguY2hhckF0KDApPT09IngiKXtoPWguc3Vic3RyaW5nKDEpO2c9MTZ9
dmFyIHM9cGFyc2VJbnQoaCxnKTtpc05hTihzKXx8KHA9cC5zdWJzdHJpbmcoMCxrKStTdHJpbmcu
ZnJvbUNoYXJDb2RlKHMpK3Auc3Vic3RyaW5nKGUrMSkpfX1hPXAucmVwbGFjZShlYSwiPCIpLnJl
cGxhY2UoZmEsIj4iKS5yZXBsYWNlKGdhLCInIikucmVwbGFjZShoYSwnIicpLnJlcGxhY2UoaWEs
IiAiKS5yZXBsYWNlKGphLAoiJiIpfWYucHVzaChhKTtuKz1hLmxlbmd0aH19bz17c291cmNlOmYu
am9pbigiIiksaDpyfTt2YXIgdj1vLnNvdXJjZTtiLnNvdXJjZT12O2IuYz0wO2IuZz1vLmg7UShp
LHYpKGIpOyQoYil9Y2F0Y2godyl7aWYoImNvbnNvbGUiaW4gd2luZG93KWNvbnNvbGUubG9nKHcm
Jncuc3RhY2s/dy5zdGFjazp3KX19dmFyIEE9InN0ciIsUj0ia3dkIixDPSJjb20iLFM9InR5cCIs
Sj0ibGl0IixFPSJwdW4iLHo9InBsbiIsUD0ic3JjIixWPSJub2NvZGUiLFo9ZnVuY3Rpb24oKXtm
b3IodmFyIGI9WyIhIiwiIT0iLCIhPT0iLCIjIiwiJSIsIiU9IiwiJiIsIiYmIiwiJiY9IiwiJj0i
LCIoIiwiKiIsIio9IiwiKz0iLCIsIiwiLT0iLCItPiIsIi8iLCIvPSIsIjoiLCI6OiIsIjsiLCI8
IiwiPDwiLCI8PD0iLCI8PSIsIj0iLCI9PSIsIj09PSIsIj4iLCI+PSIsIj4+IiwiPj49IiwiPj4+
IiwiPj4+PSIsIj8iLCJAIiwiWyIsIl4iLCJePSIsIl5eIiwiXl49IiwieyIsInwiLCJ8PSIsInx8
IiwifHw9IiwKIn4iLCJicmVhayIsImNhc2UiLCJjb250aW51ZSIsImRlbGV0ZSIsImRvIiwiZWxz
ZSIsImZpbmFsbHkiLCJpbnN0YW5jZW9mIiwicmV0dXJuIiwidGhyb3ciLCJ0cnkiLCJ0eXBlb2Yi
XSxmPSIoPzpeXnxbKy1dIixpPTA7aTxiLmxlbmd0aDsrK2kpZis9InwiK2JbaV0ucmVwbGFjZSgv
KFtePTw+OiZhLXpdKS9nLCJcXCQxIik7Zis9IilcXHMqIjtyZXR1cm4gZn0oKSxMPS8mL2csTT0v
PC9nLE49Lz4vZyxYPS9cIi9nLGVhPS8mbHQ7L2csZmE9LyZndDsvZyxnYT0vJmFwb3M7L2csaGE9
LyZxdW90Oy9nLGphPS8mYW1wOy9nLGlhPS8mbmJzcDsvZyxrYT0vW1xyXG5dL2csSz1udWxsLGFh
PVJlZ0V4cCgiW148XSt8PCEtLVtcXHNcXFNdKj8tLVw+fDwhXFxbQ0RBVEFcXFtbXFxzXFxTXSo/
XFxdXFxdPnw8Lz9bYS16QS1aXSg/OltePlwiJ118J1teJ10qJ3xcIlteXCJdKlwiKSo+fDwiLCJn
IiksYmE9L148XCEtLS8sY2E9L148IVxbQ0RBVEFcWy8sZGE9L148YnJcYi9pLFc9L148KFwvPyko
W2EtekEtWl1bYS16QS1aMC05XSopLywKbGE9eCh7a2V5d29yZHM6ImJyZWFrIGNvbnRpbnVlIGRv
IGVsc2UgZm9yIGlmIHJldHVybiB3aGlsZSBhdXRvIGNhc2UgY2hhciBjb25zdCBkZWZhdWx0IGRv
dWJsZSBlbnVtIGV4dGVybiBmbG9hdCBnb3RvIGludCBsb25nIHJlZ2lzdGVyIHNob3J0IHNpZ25l
ZCBzaXplb2Ygc3RhdGljIHN0cnVjdCBzd2l0Y2ggdHlwZWRlZiB1bmlvbiB1bnNpZ25lZCB2b2lk
IHZvbGF0aWxlIGNhdGNoIGNsYXNzIGRlbGV0ZSBmYWxzZSBpbXBvcnQgbmV3IG9wZXJhdG9yIHBy
aXZhdGUgcHJvdGVjdGVkIHB1YmxpYyB0aGlzIHRocm93IHRydWUgdHJ5IHR5cGVvZiBhbGlnbm9m
IGFsaWduX3VuaW9uIGFzbSBheGlvbSBib29sIGNvbmNlcHQgY29uY2VwdF9tYXAgY29uc3RfY2Fz
dCBjb25zdGV4cHIgZGVjbHR5cGUgZHluYW1pY19jYXN0IGV4cGxpY2l0IGV4cG9ydCBmcmllbmQg
aW5saW5lIGxhdGVfY2hlY2sgbXV0YWJsZSBuYW1lc3BhY2UgbnVsbHB0ciByZWludGVycHJldF9j
YXN0IHN0YXRpY19hc3NlcnQgc3RhdGljX2Nhc3QgdGVtcGxhdGUgdHlwZWlkIHR5cGVuYW1lIHVz
aW5nIHZpcnR1YWwgd2NoYXJfdCB3aGVyZSBicmVhayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiBy
ZXR1cm4gd2hpbGUgYXV0byBjYXNlIGNoYXIgY29uc3QgZGVmYXVsdCBkb3VibGUgZW51bSBleHRl
cm4gZmxvYXQgZ290byBpbnQgbG9uZyByZWdpc3RlciBzaG9ydCBzaWduZWQgc2l6ZW9mIHN0YXRp
YyBzdHJ1Y3Qgc3dpdGNoIHR5cGVkZWYgdW5pb24gdW5zaWduZWQgdm9pZCB2b2xhdGlsZSBjYXRj
aCBjbGFzcyBkZWxldGUgZmFsc2UgaW1wb3J0IG5ldyBvcGVyYXRvciBwcml2YXRlIHByb3RlY3Rl
ZCBwdWJsaWMgdGhpcyB0aHJvdyB0cnVlIHRyeSB0eXBlb2YgYWJzdHJhY3QgYm9vbGVhbiBieXRl
IGV4dGVuZHMgZmluYWwgZmluYWxseSBpbXBsZW1lbnRzIGltcG9ydCBpbnN0YW5jZW9mIG51bGwg
bmF0aXZlIHBhY2thZ2Ugc3RyaWN0ZnAgc3VwZXIgc3luY2hyb25pemVkIHRocm93cyB0cmFuc2ll
bnQgYXMgYmFzZSBieSBjaGVja2VkIGRlY2ltYWwgZGVsZWdhdGUgZGVzY2VuZGluZyBldmVudCBm
aXhlZCBmb3JlYWNoIGZyb20gZ3JvdXAgaW1wbGljaXQgaW4gaW50ZXJmYWNlIGludGVybmFsIGlu
dG8gaXMgbG9jayBvYmplY3Qgb3V0IG92ZXJyaWRlIG9yZGVyYnkgcGFyYW1zIHBhcnRpYWwgcmVh
ZG9ubHkgcmVmIHNieXRlIHNlYWxlZCBzdGFja2FsbG9jIHN0cmluZyBzZWxlY3QgdWludCB1bG9u
ZyB1bmNoZWNrZWQgdW5zYWZlIHVzaG9ydCB2YXIgYnJlYWsgY29udGludWUgZG8gZWxzZSBmb3Ig
aWYgcmV0dXJuIHdoaWxlIGF1dG8gY2FzZSBjaGFyIGNvbnN0IGRlZmF1bHQgZG91YmxlIGVudW0g
ZXh0ZXJuIGZsb2F0IGdvdG8gaW50IGxvbmcgcmVnaXN0ZXIgc2hvcnQgc2lnbmVkIHNpemVvZiBz
dGF0aWMgc3RydWN0IHN3aXRjaCB0eXBlZGVmIHVuaW9uIHVuc2lnbmVkIHZvaWQgdm9sYXRpbGUg
Y2F0Y2ggY2xhc3MgZGVsZXRlIGZhbHNlIGltcG9ydCBuZXcgb3BlcmF0b3IgcHJpdmF0ZSBwcm90
ZWN0ZWQgcHVibGljIHRoaXMgdGhyb3cgdHJ1ZSB0cnkgdHlwZW9mIGRlYnVnZ2VyIGV2YWwgZXhw
b3J0IGZ1bmN0aW9uIGdldCBudWxsIHNldCB1bmRlZmluZWQgdmFyIHdpdGggSW5maW5pdHkgTmFO
IGNhbGxlciBkZWxldGUgZGllIGRvIGR1bXAgZWxzaWYgZXZhbCBleGl0IGZvcmVhY2ggZm9yIGdv
dG8gaWYgaW1wb3J0IGxhc3QgbG9jYWwgbXkgbmV4dCBubyBvdXIgcHJpbnQgcGFja2FnZSByZWRv
IHJlcXVpcmUgc3ViIHVuZGVmIHVubGVzcyB1bnRpbCB1c2Ugd2FudGFycmF5IHdoaWxlIEJFR0lO
IEVORCBicmVhayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiByZXR1cm4gd2hpbGUgYW5kIGFzIGFz
c2VydCBjbGFzcyBkZWYgZGVsIGVsaWYgZXhjZXB0IGV4ZWMgZmluYWxseSBmcm9tIGdsb2JhbCBp
bXBvcnQgaW4gaXMgbGFtYmRhIG5vbmxvY2FsIG5vdCBvciBwYXNzIHByaW50IHJhaXNlIHRyeSB3
aXRoIHlpZWxkIEZhbHNlIFRydWUgTm9uZSBicmVhayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiBy
ZXR1cm4gd2hpbGUgYWxpYXMgYW5kIGJlZ2luIGNhc2UgY2xhc3MgZGVmIGRlZmluZWQgZWxzaWYg
ZW5kIGVuc3VyZSBmYWxzZSBpbiBtb2R1bGUgbmV4dCBuaWwgbm90IG9yIHJlZG8gcmVzY3VlIHJl
dHJ5IHNlbGYgc3VwZXIgdGhlbiB0cnVlIHVuZGVmIHVubGVzcyB1bnRpbCB3aGVuIHlpZWxkIEJF
R0lOIEVORCBicmVhayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiByZXR1cm4gd2hpbGUgY2FzZSBk
b25lIGVsaWYgZXNhYyBldmFsIGZpIGZ1bmN0aW9uIGluIGxvY2FsIHNldCB0aGVuIHVudGlsICIs
Cmhhc2hDb21tZW50czp0cnVlLGNTdHlsZUNvbW1lbnRzOnRydWUsbXVsdGlMaW5lU3RyaW5nczp0
cnVlLHJlZ2V4TGl0ZXJhbHM6dHJ1ZX0pLEc9e307dShsYSxbImRlZmF1bHQtY29kZSJdKTt1KEIo
W10sW1t6LC9eW148P10rL10sWyJkZWMiLC9ePCFcd1tePl0qKD86PnwkKS9dLFtDLC9ePFwhLS1b
XHNcU10qPyg/Oi1cLT58JCkvXSxbImxhbmctIiwvXjxcPyhbXHNcU10rPykoPzpcPz58JCkvXSxb
ImxhbmctIiwvXjwlKFtcc1xTXSs/KSg/OiU+fCQpL10sW0UsL14oPzo8WyU/XXxbJT9dPikvXSxb
ImxhbmctIiwvXjx4bXBcYltePl0qPihbXHNcU10rPyk8XC94bXBcYltePl0qPi9pXSxbImxhbmct
anMiLC9ePHNjcmlwdFxiW14+XSo+KFtcc1xTXSo/KSg8XC9zY3JpcHRcYltePl0qPikvaV0sWyJs
YW5nLWNzcyIsL148c3R5bGVcYltePl0qPihbXHNcU10qPykoPFwvc3R5bGVcYltePl0qPikvaV0s
WyJsYW5nLWluLnRhZyIsL14oPFwvP1thLXpdW148Pl0qPikvaV1dKSxbImRlZmF1bHQtbWFya3Vw
IiwKImh0bSIsImh0bWwiLCJteG1sIiwieGh0bWwiLCJ4bWwiLCJ4c2wiXSk7dShCKFtbeiwvXltc
c10rLyxudWxsLCIgXHRcclxuIl0sWyJhdHYiLC9eKD86XCJbXlwiXSpcIj98XCdbXlwnXSpcJz8p
LyxudWxsLCJcIiciXV0sW1sidGFnIiwvXl48XC8/W2Etel0oPzpbXHcuOi1dKlx3KT98XC8/PiQv
aV0sWyJhdG4iLC9eKD8hc3R5bGVbXHM9XXxvbilbYS16XSg/OltcdzotXSpcdyk/L2ldLFsibGFu
Zy11cS52YWwiLC9ePVxzKihbXj5cJ1wiXHNdKig/OltePlwnXCJcc1wvXXxcLyg/PVxzKSkpL10s
W0UsL15bPTw+XC9dKy9dLFsibGFuZy1qcyIsL15vblx3K1xzKj1ccypcIihbXlwiXSspXCIvaV0s
WyJsYW5nLWpzIiwvXm9uXHcrXHMqPVxzKlwnKFteXCddKylcJy9pXSxbImxhbmctanMiLC9eb25c
dytccyo9XHMqKFteXCJcJz5cc10rKS9pXSxbImxhbmctY3NzIiwvXnN0eWxlXHMqPVxzKlwiKFte
XCJdKylcIi9pXSxbImxhbmctY3NzIiwvXnN0eWxlXHMqPVxzKlwnKFteXCddKylcJy9pXSwKWyJs
YW5nLWNzcyIsL15zdHlsZVxzKj1ccyooW15cIlwnPlxzXSspL2ldXSksWyJpbi50YWciXSk7dShC
KFtdLFtbImF0diIsL15bXHNcU10rL11dKSxbInVxLnZhbCJdKTt1KHgoe2tleXdvcmRzOiJicmVh
ayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiByZXR1cm4gd2hpbGUgYXV0byBjYXNlIGNoYXIgY29u
c3QgZGVmYXVsdCBkb3VibGUgZW51bSBleHRlcm4gZmxvYXQgZ290byBpbnQgbG9uZyByZWdpc3Rl
ciBzaG9ydCBzaWduZWQgc2l6ZW9mIHN0YXRpYyBzdHJ1Y3Qgc3dpdGNoIHR5cGVkZWYgdW5pb24g
dW5zaWduZWQgdm9pZCB2b2xhdGlsZSBjYXRjaCBjbGFzcyBkZWxldGUgZmFsc2UgaW1wb3J0IG5l
dyBvcGVyYXRvciBwcml2YXRlIHByb3RlY3RlZCBwdWJsaWMgdGhpcyB0aHJvdyB0cnVlIHRyeSB0
eXBlb2YgYWxpZ25vZiBhbGlnbl91bmlvbiBhc20gYXhpb20gYm9vbCBjb25jZXB0IGNvbmNlcHRf
bWFwIGNvbnN0X2Nhc3QgY29uc3RleHByIGRlY2x0eXBlIGR5bmFtaWNfY2FzdCBleHBsaWNpdCBl
eHBvcnQgZnJpZW5kIGlubGluZSBsYXRlX2NoZWNrIG11dGFibGUgbmFtZXNwYWNlIG51bGxwdHIg
cmVpbnRlcnByZXRfY2FzdCBzdGF0aWNfYXNzZXJ0IHN0YXRpY19jYXN0IHRlbXBsYXRlIHR5cGVp
ZCB0eXBlbmFtZSB1c2luZyB2aXJ0dWFsIHdjaGFyX3Qgd2hlcmUgIiwKaGFzaENvbW1lbnRzOnRy
dWUsY1N0eWxlQ29tbWVudHM6dHJ1ZX0pLFsiYyIsImNjIiwiY3BwIiwiY3h4IiwiY3ljIiwibSJd
KTt1KHgoe2tleXdvcmRzOiJudWxsIHRydWUgZmFsc2UifSksWyJqc29uIl0pO3UoeCh7a2V5d29y
ZHM6ImJyZWFrIGNvbnRpbnVlIGRvIGVsc2UgZm9yIGlmIHJldHVybiB3aGlsZSBhdXRvIGNhc2Ug
Y2hhciBjb25zdCBkZWZhdWx0IGRvdWJsZSBlbnVtIGV4dGVybiBmbG9hdCBnb3RvIGludCBsb25n
IHJlZ2lzdGVyIHNob3J0IHNpZ25lZCBzaXplb2Ygc3RhdGljIHN0cnVjdCBzd2l0Y2ggdHlwZWRl
ZiB1bmlvbiB1bnNpZ25lZCB2b2lkIHZvbGF0aWxlIGNhdGNoIGNsYXNzIGRlbGV0ZSBmYWxzZSBp
bXBvcnQgbmV3IG9wZXJhdG9yIHByaXZhdGUgcHJvdGVjdGVkIHB1YmxpYyB0aGlzIHRocm93IHRy
dWUgdHJ5IHR5cGVvZiBhYnN0cmFjdCBib29sZWFuIGJ5dGUgZXh0ZW5kcyBmaW5hbCBmaW5hbGx5
IGltcGxlbWVudHMgaW1wb3J0IGluc3RhbmNlb2YgbnVsbCBuYXRpdmUgcGFja2FnZSBzdHJpY3Rm
cCBzdXBlciBzeW5jaHJvbml6ZWQgdGhyb3dzIHRyYW5zaWVudCBhcyBiYXNlIGJ5IGNoZWNrZWQg
ZGVjaW1hbCBkZWxlZ2F0ZSBkZXNjZW5kaW5nIGV2ZW50IGZpeGVkIGZvcmVhY2ggZnJvbSBncm91
cCBpbXBsaWNpdCBpbiBpbnRlcmZhY2UgaW50ZXJuYWwgaW50byBpcyBsb2NrIG9iamVjdCBvdXQg
b3ZlcnJpZGUgb3JkZXJieSBwYXJhbXMgcGFydGlhbCByZWFkb25seSByZWYgc2J5dGUgc2VhbGVk
IHN0YWNrYWxsb2Mgc3RyaW5nIHNlbGVjdCB1aW50IHVsb25nIHVuY2hlY2tlZCB1bnNhZmUgdXNo
b3J0IHZhciAiLApoYXNoQ29tbWVudHM6dHJ1ZSxjU3R5bGVDb21tZW50czp0cnVlLHZlcmJhdGlt
U3RyaW5nczp0cnVlfSksWyJjcyJdKTt1KHgoe2tleXdvcmRzOiJicmVhayBjb250aW51ZSBkbyBl
bHNlIGZvciBpZiByZXR1cm4gd2hpbGUgYXV0byBjYXNlIGNoYXIgY29uc3QgZGVmYXVsdCBkb3Vi
bGUgZW51bSBleHRlcm4gZmxvYXQgZ290byBpbnQgbG9uZyByZWdpc3RlciBzaG9ydCBzaWduZWQg
c2l6ZW9mIHN0YXRpYyBzdHJ1Y3Qgc3dpdGNoIHR5cGVkZWYgdW5pb24gdW5zaWduZWQgdm9pZCB2
b2xhdGlsZSBjYXRjaCBjbGFzcyBkZWxldGUgZmFsc2UgaW1wb3J0IG5ldyBvcGVyYXRvciBwcml2
YXRlIHByb3RlY3RlZCBwdWJsaWMgdGhpcyB0aHJvdyB0cnVlIHRyeSB0eXBlb2YgYWJzdHJhY3Qg
Ym9vbGVhbiBieXRlIGV4dGVuZHMgZmluYWwgZmluYWxseSBpbXBsZW1lbnRzIGltcG9ydCBpbnN0
YW5jZW9mIG51bGwgbmF0aXZlIHBhY2thZ2Ugc3RyaWN0ZnAgc3VwZXIgc3luY2hyb25pemVkIHRo
cm93cyB0cmFuc2llbnQgIiwKY1N0eWxlQ29tbWVudHM6dHJ1ZX0pLFsiamF2YSJdKTt1KHgoe2tl
eXdvcmRzOiJicmVhayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiByZXR1cm4gd2hpbGUgY2FzZSBk
b25lIGVsaWYgZXNhYyBldmFsIGZpIGZ1bmN0aW9uIGluIGxvY2FsIHNldCB0aGVuIHVudGlsICIs
aGFzaENvbW1lbnRzOnRydWUsbXVsdGlMaW5lU3RyaW5nczp0cnVlfSksWyJic2giLCJjc2giLCJz
aCJdKTt1KHgoe2tleXdvcmRzOiJicmVhayBjb250aW51ZSBkbyBlbHNlIGZvciBpZiByZXR1cm4g
d2hpbGUgYW5kIGFzIGFzc2VydCBjbGFzcyBkZWYgZGVsIGVsaWYgZXhjZXB0IGV4ZWMgZmluYWxs
eSBmcm9tIGdsb2JhbCBpbXBvcnQgaW4gaXMgbGFtYmRhIG5vbmxvY2FsIG5vdCBvciBwYXNzIHBy
aW50IHJhaXNlIHRyeSB3aXRoIHlpZWxkIEZhbHNlIFRydWUgTm9uZSAiLGhhc2hDb21tZW50czp0
cnVlLG11bHRpTGluZVN0cmluZ3M6dHJ1ZSx0cmlwbGVRdW90ZWRTdHJpbmdzOnRydWV9KSxbImN2
IiwicHkiXSk7CnUoeCh7a2V5d29yZHM6ImNhbGxlciBkZWxldGUgZGllIGRvIGR1bXAgZWxzaWYg
ZXZhbCBleGl0IGZvcmVhY2ggZm9yIGdvdG8gaWYgaW1wb3J0IGxhc3QgbG9jYWwgbXkgbmV4dCBu
byBvdXIgcHJpbnQgcGFja2FnZSByZWRvIHJlcXVpcmUgc3ViIHVuZGVmIHVubGVzcyB1bnRpbCB1
c2Ugd2FudGFycmF5IHdoaWxlIEJFR0lOIEVORCAiLGhhc2hDb21tZW50czp0cnVlLG11bHRpTGlu
ZVN0cmluZ3M6dHJ1ZSxyZWdleExpdGVyYWxzOnRydWV9KSxbInBlcmwiLCJwbCIsInBtIl0pO3Uo
eCh7a2V5d29yZHM6ImJyZWFrIGNvbnRpbnVlIGRvIGVsc2UgZm9yIGlmIHJldHVybiB3aGlsZSBh
bGlhcyBhbmQgYmVnaW4gY2FzZSBjbGFzcyBkZWYgZGVmaW5lZCBlbHNpZiBlbmQgZW5zdXJlIGZh
bHNlIGluIG1vZHVsZSBuZXh0IG5pbCBub3Qgb3IgcmVkbyByZXNjdWUgcmV0cnkgc2VsZiBzdXBl
ciB0aGVuIHRydWUgdW5kZWYgdW5sZXNzIHVudGlsIHdoZW4geWllbGQgQkVHSU4gRU5EICIsaGFz
aENvbW1lbnRzOnRydWUsCm11bHRpTGluZVN0cmluZ3M6dHJ1ZSxyZWdleExpdGVyYWxzOnRydWV9
KSxbInJiIl0pO3UoeCh7a2V5d29yZHM6ImJyZWFrIGNvbnRpbnVlIGRvIGVsc2UgZm9yIGlmIHJl
dHVybiB3aGlsZSBhdXRvIGNhc2UgY2hhciBjb25zdCBkZWZhdWx0IGRvdWJsZSBlbnVtIGV4dGVy
biBmbG9hdCBnb3RvIGludCBsb25nIHJlZ2lzdGVyIHNob3J0IHNpZ25lZCBzaXplb2Ygc3RhdGlj
IHN0cnVjdCBzd2l0Y2ggdHlwZWRlZiB1bmlvbiB1bnNpZ25lZCB2b2lkIHZvbGF0aWxlIGNhdGNo
IGNsYXNzIGRlbGV0ZSBmYWxzZSBpbXBvcnQgbmV3IG9wZXJhdG9yIHByaXZhdGUgcHJvdGVjdGVk
IHB1YmxpYyB0aGlzIHRocm93IHRydWUgdHJ5IHR5cGVvZiBkZWJ1Z2dlciBldmFsIGV4cG9ydCBm
dW5jdGlvbiBnZXQgbnVsbCBzZXQgdW5kZWZpbmVkIHZhciB3aXRoIEluZmluaXR5IE5hTiAiLGNT
dHlsZUNvbW1lbnRzOnRydWUscmVnZXhMaXRlcmFsczp0cnVlfSksWyJqcyJdKTt1KEIoW10sW1tB
LC9eW1xzXFNdKy9dXSksClsicmVnZXgiXSk7d2luZG93LlBSX25vcm1hbGl6ZWRIdG1sPUg7d2lu
ZG93LnByZXR0eVByaW50T25lPWZ1bmN0aW9uKGIsZil7dmFyIGk9e2Y6YixlOmZ9O1UoaSk7cmV0
dXJuIGkuYX07d2luZG93LnByZXR0eVByaW50PWZ1bmN0aW9uKGIpe2Z1bmN0aW9uIGYoKXtmb3Io
dmFyIHQ9d2luZG93LlBSX1NIT1VMRF9VU0VfQ09OVElOVUFUSU9OP2oubm93KCkrMjUwOkluZmlu
aXR5O3E8by5sZW5ndGgmJmoubm93KCk8dDtxKyspe3ZhciBwPW9bcV07aWYocC5jbGFzc05hbWUm
JnAuY2xhc3NOYW1lLmluZGV4T2YoInByZXR0eXByaW50Iik+PTApe3ZhciBjPXAuY2xhc3NOYW1l
Lm1hdGNoKC9cYmxhbmctKFx3KylcYi8pO2lmKGMpYz1jWzFdO2Zvcih2YXIgZD1mYWxzZSxhPXAu
cGFyZW50Tm9kZTthO2E9YS5wYXJlbnROb2RlKWlmKChhLnRhZ05hbWU9PT0icHJlInx8YS50YWdO
YW1lPT09ImNvZGUifHxhLnRhZ05hbWU9PT0ieG1wIikmJmEuY2xhc3NOYW1lJiZhLmNsYXNzTmFt
ZS5pbmRleE9mKCJwcmV0dHlwcmludCIpPj0KMCl7ZD10cnVlO2JyZWFrfWlmKCFkKXthPXA7aWYo
bnVsbD09PUspe2Q9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgiUFJFIik7ZC5hcHBlbmRDaGlsZChk
b2N1bWVudC5jcmVhdGVUZXh0Tm9kZSgnPCFET0NUWVBFIGZvbyBQVUJMSUMgImZvbyBiYXIiPlxu
PGZvbyAvPicpKTtLPSEvPC8udGVzdChkLmlubmVySFRNTCl9aWYoSyl7ZD1hLmlubmVySFRNTDtp
ZigiWE1QIj09PWEudGFnTmFtZSlkPXkoZCk7ZWxzZXthPWE7aWYoIlBSRSI9PT1hLnRhZ05hbWUp
YT10cnVlO2Vsc2UgaWYoa2EudGVzdChkKSl7dmFyIGs9IiI7aWYoYS5jdXJyZW50U3R5bGUpaz1h
LmN1cnJlbnRTdHlsZS53aGl0ZVNwYWNlO2Vsc2UgaWYod2luZG93LmdldENvbXB1dGVkU3R5bGUp
az13aW5kb3cuZ2V0Q29tcHV0ZWRTdHlsZShhLG51bGwpLndoaXRlU3BhY2U7YT0ha3x8az09PSJw
cmUifWVsc2UgYT10cnVlO2F8fChkPWQucmVwbGFjZSgvKDxiclxzKlwvPz4pW1xyXG5dKy9nLCIk
MSIpLnJlcGxhY2UoLyg/OltcclxuXStbIFx0XSopKy9nLAoiICIpKX1kPWR9ZWxzZXtkPVtdO2Zv
cihhPWEuZmlyc3RDaGlsZDthO2E9YS5uZXh0U2libGluZylIKGEsZCk7ZD1kLmpvaW4oIiIpfWQ9
ZC5yZXBsYWNlKC8oPzpcclxuP3xcbikkLywiIik7bT17ZjpkLGU6YyxiOnB9O1UobSk7aWYocD1t
LmEpe2M9bS5iO2lmKCJYTVAiPT09Yy50YWdOYW1lKXtkPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQo
IlBSRSIpO2ZvcihhPTA7YTxjLmF0dHJpYnV0ZXMubGVuZ3RoOysrYSl7az1jLmF0dHJpYnV0ZXNb
YV07aWYoay5zcGVjaWZpZWQpaWYoay5uYW1lLnRvTG93ZXJDYXNlKCk9PT0iY2xhc3MiKWQuY2xh
c3NOYW1lPWsudmFsdWU7ZWxzZSBkLnNldEF0dHJpYnV0ZShrLm5hbWUsay52YWx1ZSl9ZC5pbm5l
ckhUTUw9cDtjLnBhcmVudE5vZGUucmVwbGFjZUNoaWxkKGQsYyl9ZWxzZSBjLmlubmVySFRNTD1w
fX19fWlmKHE8by5sZW5ndGgpc2V0VGltZW91dChmLDI1MCk7ZWxzZSBiJiZiKCl9Zm9yKHZhciBp
PVtkb2N1bWVudC5nZXRFbGVtZW50c0J5VGFnTmFtZSgicHJlIiksCmRvY3VtZW50LmdldEVsZW1l
bnRzQnlUYWdOYW1lKCJjb2RlIiksZG9jdW1lbnQuZ2V0RWxlbWVudHNCeVRhZ05hbWUoInhtcCIp
XSxvPVtdLGw9MDtsPGkubGVuZ3RoOysrbClmb3IodmFyIG49MCxyPWlbbF0ubGVuZ3RoO248cjsr
K24pby5wdXNoKGlbbF1bbl0pO2k9bnVsbDt2YXIgaj1EYXRlO2oubm93fHwoaj17bm93OmZ1bmN0
aW9uKCl7cmV0dXJuKG5ldyBEYXRlKS5nZXRUaW1lKCl9fSk7dmFyIHE9MCxtO2YoKX07d2luZG93
LlBSPXtjb21iaW5lUHJlZml4UGF0dGVybnM6TyxjcmVhdGVTaW1wbGVMZXhlcjpCLHJlZ2lzdGVy
TGFuZ0hhbmRsZXI6dSxzb3VyY2VEZWNvcmF0b3I6eCxQUl9BVFRSSUJfTkFNRToiYXRuIixQUl9B
VFRSSUJfVkFMVUU6ImF0diIsUFJfQ09NTUVOVDpDLFBSX0RFQ0xBUkFUSU9OOiJkZWMiLFBSX0tF
WVdPUkQ6UixQUl9MSVRFUkFMOkosUFJfTk9DT0RFOlYsUFJfUExBSU46eixQUl9QVU5DVFVBVElP
TjpFLFBSX1NPVVJDRTpQLFBSX1NUUklORzpBLApQUl9UQUc6InRhZyIsUFJfVFlQRTpTfX0pKCk=

__END__

=head1 NAME

Mojolicious::Static - Serve Static Files

=head1 SYNOPSIS

    use Mojolicious::Static;

=head1 DESCRIPTION

L<Mojolicious::Static> is a dispatcher for static files with C<Range> and
C<If-Modified-Since> support.

=head1 FILES

L<Mojolicious::Static> has a few popular static files bundled.

=head2 C<amelia.png>

Amelia Perl logo.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-SA License, Version 3.0
L<http://creativecommons.org/licenses/by-sa/3.0>.

=head2 C<favicon.ico>

Mojolicious favicon.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<mojolicious-arrow.png>

Mojolicious arrow for C<not_found> template.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<mojolicious-black.png>

Black Mojolicious logo.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<mojolicious-box.png>

Mojolicious box for C<not_found> template.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<mojolicious-clouds.png>

Mojolicious clouds for C<not_found> template.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<mojolicious-pinstripe.gif>

Mojolicious pinstripe effect for multiple templates.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<mojolicious-white.png>

White Mojolicious logo.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C<css/prettify-mojo.css>

Mojolicious theme for C<prettify.js>.

    Copyright (C) 2010-2011, Sebastian Riedel.

Licensed under the CC-ND License, Version 3.0
L<http://creativecommons.org/licenses/by-nc-nd/3.0>.

=head2 C</js/jquery.js>

   Version 1.5

jQuery is a fast and concise JavaScript Library that simplifies HTML document
traversing, event handling, animating, and Ajax interactions for rapid web
development. jQuery is designed to change the way that you write JavaScript.

    Copyright 2011, John Resig.

Licensed under the MIT License, L<http://creativecommons.org/licenses/MIT>.

=head2 C</js/prettify.js>

    Version 21-Jul-2010

A Javascript module and CSS file that allows syntax highlighting of source
code snippets in an html page.

    Copyright (C) 2006, Google Inc.

Licensed under the Apache License, Version 2.0
L<http://www.apache.org/licenses/LICENSE-2.0>.

=head1 ATTRIBUTES

L<Mojolicious::Static> implements the following attributes.

=head2 C<default_static_class>

    my $class = $static->default_static_class;
    $static   = $static->default_static_class('main');

The dispatcher will use this class to look for files in the C<DATA> section.

=head2 C<root>

    my $root = $static->root;
    $static  = $static->root('/foo/bar/files');

Directory to serve static files from.

=head1 METHODS

L<Mojolicious::Static> inherits all methods from L<Mojo::Base>
and implements the following ones.

=head2 C<dispatch>

    my $success = $static->dispatch($c);

Dispatch a L<Mojolicious::Controller> object.

=head2 C<serve>

    my $success = $static->serve($c, 'foo/bar.html');

Serve a specific file.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
