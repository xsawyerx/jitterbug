package jitterbug;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use jitterbug::Plugin::Template;

our $VERSION = '0.1';

load_app 'jitterbug::Hook',       prefix => '/hook';
load_app 'jitterbug::Project',    prefix => '/project';
load_app 'jitterbug::WebService', prefix => '/api';
#load_app 'jitterbug::Task',       prefix => '/task';

get '/' => sub {

    my @projects = ();

    my $projects = schema->resultset('Project')->search();
    while ( my $project = $projects->next ) {
        my $owner     = from_json( $project->owner );
        my $proj_desc = {
            description => $project->description,
            name        => $project->name,
            url         => $project->url,
            owner_name  => $owner->{name},
        };

        my $last_commit =
          schema->resultset('Commit')
          ->search( { projectid => $project->projectid }, {order_by => {-desc => 'timestamp'}} )->first();

        if ($last_commit) {
            # XXX see what data to store here
            $proj_desc->{last_build} = from_json($last_commit->content);
        }

        push @projects, $proj_desc;
    }

    @projects =
      sort { $b->{last_build}->{timestamp} cmp $a->{last_build}->{timestamp} }
      @projects;

    template 'index', {projects => \@projects};
};

true;

__END__

=head1 NAME

jitterbug - Contiuous integration for Perl modules on Github.com

=head1 DESCRIPTION

Jitterbug accepts hooks that describe what to monitor. If you don't use Github,
you'll need to write a script that will send a JSON request to Jitterbug to add
your repository. There is a template available at C<t/data/>.

There are plans to write a commit hook that will do the job as well.

=head1 SETUP

=head2 Configuring Github

In the I<admin> section in your repo (
L<https://github.com/franckcuny/net-http-spore/edit>), pick the I<service hook>
menu on the left, choose post receive url and put the url of your Jitterbug
setup (like L<http://myjitterbug.org/hook/>).

You can protect the </hook/> path with an htaccess (and use
L<http://user:pass@myjitterbug.org/hook/>) or you can use
L<Plack::Middleware::Auth::Basic> with an C<enable_if> on the path to match
I</hook/>.

You can find more information on post-receive-hooks
L<http://help.github.com/post-receive-hooks/|here>.

=head2 Running the builder

Once Jitterbug is running (the web service part), you need to execute the script
found in I<scripts/builder.pl> that will monitor any incoming commits in the
database and run the build for them.

=head2 Testing without Github

You can try your setup with the I<eg/post_hook.t> file. Edit this file to point
the url to your local Jitterbug and it will insert a valid commit for Dancer
so you can try it locally without doing anything on Github yet.

