package Text::Restructured::DOM;

# $Id$
# Copyright (C) 2002-2005 Freescale Semiconductor, Inc.
# Distributed under terms of the Perl license, which is the disjunction of
# the GNU General Public License (GPL) and the Artistic License.

# This package contains routines for Document Object Model (DOM) objects.
# A DOM object is the prest equivalent of a doctree object.

# Data structures:
#   _`Text::Restructured::DOM`: Recursive hash reference with following 
#     keys:
#       ``tag``:      The name of the tag of the DOM object
#       ``attr``:     Reference to hash of attribute/value pairs
#       ``content``:  Reference to array of DOM objects
#       ``text``:     Contains the literal text for #PCDATA
#       ``internal``: Reference to hash of internal attribute/value pairs
#       ``source``:   Optionally contains the source
#       ``lineno``:   Optionally contains the line number
#       ``lit``:      Optionally contains the literal text
#       ``val``:      The value returned by the DOM's handler (added 
#                     during traversal of the writer's handlers)

# Global variables:
#   ``%DOM::PARENT``: hash whose keys are DOM references and whose values are
#                     a reference to the DOM object of the parent.
#                     Should only be accessed indirectly through the 
#                     ``DOM::parent`` method.

use strict;
use vars qw(%PARENT);

# CLASS METHOD.
# Creates a new DOM object.
# Arguments: (optional) tag, (optional) list of attribute/value pairs
# Returns: DOM object
sub new {
    my ($class, $tag, %attr) = @_;

    my $dom = bless { };
    $dom->{tag} = $tag if defined $tag;
    $dom->{attr} = {%attr} if %attr;
    $dom->{content} = [];
    return $dom;
}

# CLASS METHOD.
# Creates a new DOM object that is a "#PCDATA" type.
# Arguments: text
# Returns: DOM object
sub newPCDATA {
    my ($class, $text) = @_;

    return bless {tag=>'#PCDATA', text=>$text, content=>[] };
}

# INSTANCE METHOD.
# Appends to the contents of a DOM object.
# Arguments: DOM objects to append
# Returns: The new number of contents
sub append : method {
    my ($dom, @doms) = @_;

    @PARENT{@doms} = ($dom) x @doms;
    push @{$dom->{content}}, @doms;
}

# INSTANCE METHOD.
# Returns the content objects the DOM object has
# Arguments: None
# Returns: Array of content DOM objects
sub contents : method {
    my ($dom, @doms) = @_;

    return @{$dom->{content}};
}

# INSTANCE METHOD.
# Returns the index of a child in the contents (-1 if it does not occur).
# Arguments: child DOM object
# Returns: index number
sub index : method {
    my ($dom, $child) = @_;
    my $i;
    for ($i=0; $i<@{$dom->{content}}; $i++) {
	return $i if $dom->{content}[$i] == $child;
    }
    return -1;
}

# INSTANCE METHOD.
# Returns the last DOM in the contents of a DOM.
# Arguments: None
# Returns: last DOM object (or undefined)
sub last : method {
    my ($dom) = @_;

    my $last;
    if (@{$dom->{content}}) {
	$last = $dom->{content}[-1];
    }
    return $last;
}

# INSTANCE METHOD.
# Returns the next DOM in the logical structure of the tree.  If the
# given DOM is the last in a section or list, this routine may have to
# go up in the tree to find the next object.
# Arguments: optional regular expression for tags to ignore
# Returns: next DOM or undef
sub next : method {
    my ($dom, $ignore) = @_;

    my $parent = $dom->parent();
    my $indx = $parent->index($dom) + 1;
    my $cur_parent = $parent;
    while (defined $cur_parent) {
	while ($indx < $cur_parent->num_contents()) {
	    my $tag = $cur_parent->{content}[$indx]{tag};
	    if (defined $ignore && $tag =~ /^(?:$ignore)$/) {
		# It's a skippable tag
		$indx++;
		next;
	    }
	    return $cur_parent->{content}[$indx];
	}
	my $new_parent = $cur_parent->parent();
	return unless defined $new_parent;
	$indx = $new_parent->index($cur_parent) + 1;
	$cur_parent = $new_parent;
    }
}

# INSTANCE METHOD.
# Returns the number of content objects the DOM object has
# Arguments: None
# Returns: Number of elements
sub num_contents : method {
    my ($dom, @doms) = @_;

    return 0+@{$dom->{content}};
}

# INSTANCE METHOD.
# Returns the parent DOM of an instance.
# Arguments: None
# Returns: The DOM object's parent
sub parent : method {
    my ($dom) = @_;

    return $PARENT{$dom};
}

# INSTANCE METHOD.
# Puts the arguments at the beginning of the contents of a DOM object.
# Arguments: DOM objects to prepend
# Returns: The new number of objects
sub prepend : method {
    my ($dom, @doms) = @_;

    @PARENT{@doms} = ($dom) x @doms;
    unshift (@{$dom->{content}}, @doms);
}

# INSTANCE METHOD.
# Goes through a DOM object recursively calling a subroutine on every
# element.  It can do either preorder, postorder or bothorder traversal
# (defaults to postorder).  Unlike Reshape, it does not modify the
# children of the nodes it visits.
# Arguments: callback routine, optional 'pre'/'post'/'both',
#            optional additional arguments to be propagated
# Returns: Stop recursion flag
# Callback routine arguments: target DOM, 'pre'/'post',
#                             optional additional arguments
# Callback routine returns: non-zero in 'pre' mode to avoid further recursion.
sub Recurse : method {
    my($dom, $sub, $when, @args) = @_;

    $when = 'post' unless defined $when;
    my $stop;
    if ($when =~ /^(pre|both)$/) {
	$stop = eval { &{$sub}($dom, 'pre', @args) };
	die "Error: $sub: $@" if $@;
    }
    return if $stop;

    my @contents = @{$dom->{content}};
    my $i;
    for ($i=0; $i<@contents; $i++) {
	my $content = $contents[$i];
	$content->Recurse($sub, $when, @args);
    }

    if ($when ne 'pre') {
	eval { &{$sub}($dom, 'post', @args) };
	die "Error: $sub: $@" if $@;
    }
}

# INSTANCE METHOD.
# Replaces the contents of a DOM object with a new set of objects.
# Arguments: DOM objects to replace
# Returns: None
sub replace : method {
    my ($dom, @doms) = @_;

    @PARENT{@doms} = ($dom) x @doms;
    @{$dom->{content}} = @doms;
    return;
}

# INSTANCE METHOD.
# Goes through a DOM object recursively calling a subroutine on every
# element.  It can do either preorder, postorder or bothorder traversal
# (defaults to postorder).
# Arguments: callback routine, optional 'pre'/'post'/'both',
#            optional additional arguments to be propagated
# Returns: Reference to new set objects to replace the current object
# Callback routine arguments: target DOM, 'pre'/'post',
#                             optional additional arguments
# Callback routine returns: whatever list of DOM objects are to be 
#                           substituted for the current node (this
#                           list is returned on the 'post' call if
#                           'both' is selected).
sub Reshape : method {
    my($dom, $sub, $when, @args) = @_;

    $when = 'post' unless defined $when;
    my @newdom;
    if ($when =~ /^(pre|both)$/) {
	@newdom = eval { &{$sub}($dom, 'pre', @args) };
	die "Error: $sub: $@" if $@;
    }

    my @contents = @{$dom->{content}};
    my $i;
    my $replace = 0;
    for ($i=0; $i<@contents; $i++) {
	my $content = $contents[$i];
	my @new_contents = grep(defined $_,
				$content->Reshape($sub, $when, @args));
	$dom->splice($replace, 1, @new_contents);
	$replace += @new_contents;
    }

    if ($when ne 'pre') {
	@newdom = eval { &{$sub}($dom, 'post', @args) };
	die "Error: $sub: $@" if $@;
    }

    return @newdom;
}

# INSTANCE METHOD.
# Splices objects into the contents of a DOM object.
# Arguments: start index, number to replace, list of DOM objects to splice
# Returns: Array of removed objects
sub splice : method {
    my ($dom, $index, $n, @doms) = @_;

    @PARENT{@doms} = ($dom) x @doms;
    return splice(@{$dom->{content}}, $index, $n, @doms);
}

# INSTANCE METHOD.
# Substitutes a different set of DOM objects for a given DOM object in the
# contents of its parent.
# Arguments: list of DOM objects
# Returns: None
sub substitute : method {
    my($dom, @new_doms) = @_;

    my $parent = $dom->parent;
    return unless $parent;
    my $index = $parent->index($dom);
    return if $index < 0;
    splice @{$parent->{content}}, $index, 1, @new_doms;
    delete $PARENT{$dom};
    @PARENT{@new_doms} = ($parent) x @new_doms;
}


# Parses a file in the DOM (pseudo-XML) format.
# Arguments: First line of file
# Returns: DOM object
# Uses globals: <> file handle
sub Parse {
    my ($first_line) = @_;
    my $last_indent = -1;
    my @stack;
    my @indents;
    my $tos;	# top of stack
    my $main;
    $_ = $first_line;
    do {
	/(\s*).*/;
	my $spaces = $1;
	my $indent = length($spaces);
	if (@stack > 0) {
	    my $i;
	    for ($i=0; $i < @indents; $i++) {
		last if $indent <= $indents[$i]+1;
	    }
	    splice(@stack, $i);
	    splice(@indents, $i);
	    $tos = $stack[-1];
	}

	if (/^(\s*)<(\w+)\s*([^>]*)>\s*$/) {
	    my ($spaces, $tag, $attrlist) = ($1, $2, $3);
	    my $dom = new Text::Restructured::DOM($tag);
	    while ($attrlist ne '') {
		if ($attrlist =~ s/^([\w:]+)=([\"\'])([^\"]*)\2\s*//) {
		    $dom->{attr}{$1} = $3;
		}
		elsif ($attrlist =~ s/^(\w+)\s*//) {
		    $dom->{attr}{$1} = undef;
		}
		else {
		    goto pcdata;
		}
	    }
	    $tos->append($dom) if $tos;
	    if (@stack > 0) {
		$tos = $dom;
	    }
	    else {
		$main = $dom;
	    }
	    push (@stack, $dom);
	    push (@indents, $indent);
	    $tos = $dom;
	}
	else {
	  pcdata:
	    substr($_,0,$indents[-1]+4) = "";
	    chomp;
	    my $text = $_;
	    my $ncontent = @{$tos->{content}};
	    if ($ncontent > 0 &&
		$tos->{content}[$ncontent-1]{tag} eq '#PCDATA') {
		$tos->{content}[$ncontent-1]{text} .= "$text\n";
	    }
	    else {
		my $dom = newPCDATA Text::Restructured::DOM("$text\n");
		$tos->append($dom);
	    }
	}
    } while <>;

    $main->{attr}{source} = $main::opt_D{source} || $ARGV;
    return $main;
}


1;
