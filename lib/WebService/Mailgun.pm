package WebService::Mailgun;
use 5.008001;
use strict;
use warnings;

use Furl;
use JSON::XS;
use URI;

our $VERSION = "0.02";
our $API_BASE = 'api.mailgun.net/v3';

use Class::Accessor::Lite (
    new => 1,
    rw  => [qw(api_key domain)],
);

sub decode_response ($) {
    my $res = shift;

    if ($res->is_success) {
        return decode_json $res->content;
    } else {
        my $json = decode_json $res->content;
        warn $json->{message};
        die $res->status_line;
    }
}

sub recursive {
    my ($self, $method, $key) = @_;

    $key //= 'items';
    my $query = '';
    my @result;

    while (1) {
        my $api_uri = URI->new($self->api_url($method));
        $api_uri->query($query);
        my $res = $self->client->get($api_uri->as_string);
        my $json = decode_response $res;
        last unless scalar @{$json->{$key}};
        push @result, @{$json->{$key}};
        my $next_uri = URI->new($json->{paging}->{next});
        $query = $next_uri->query;
    }

    return \@result;
}

sub client {
    my $self = shift;

    $self->{_client} //= Furl->new(
        agent => __PACKAGE__ . '/' . $VERSION,
    );
}

sub api_url {
    my ($self, $method) = @_;

    sprintf 'https://api:%s@%s/%s',
        $self->api_key, $API_BASE, $method;
}

sub domain_api_url {
    my ($self, $method) = @_;

    sprintf 'https://api:%s@%s/%s/%s',
        $self->api_key, $API_BASE, $self->domain, $method;
}

sub message {
    my ($self, $args) = @_;

    my $res = $self->client->post($self->domain_api_url('messages'), [], $args);
    decode_response $res;
}

sub lists {
    my $self = shift;

    return $self->recursive('lists/pages');
}

sub add_list {
    my ($self, $args) = @_;

    my $res = $self->client->post($self->api_url("lists"), [], $args);
    decode_response $res;
}

sub list {
    my ($self, $address) = @_;

    my $res = $self->client->get($self->api_url("lists/$address"));
    my $json = decode_response $res;
    return $json->{list};
}

sub update_list {
    my ($self, $address, $args) = @_;

    my $res = $self->client->put($self->api_url("lists/$address"), [], $args);
    decode_response $res;
}

sub delete_list {
    my ($self, $address) = @_;

    my $res = $self->client->delete($self->api_url("lists/$address"));
    decode_response $res;
}

sub list_members {
    my ($self, $address) = @_;

    return $self->recursive("lists/$address/members/pages");
}

sub add_list_member {
    my ($self, $address, $args) = @_;

    my $res = $self->client->post(
        $self->api_url("lists/$address/members"), [], $args);
    decode_response $res;
}

sub add_list_members {
    my ($self, $address, $args) = @_;

    my $res = $self->client->post(
        $self->api_url("lists/$address/members.json"), [], $args);
    decode_response $res;
}

sub list_member {
    my ($self, $address, $member) = @_;

    my $res = $self->client->get($self->api_url("lists/$address/members/$member"));
    my $json = decode_response $res;
    return $json->{member};
}

sub update_list_member {
    my ($self, $address, $member, $args) = @_;

    my $res = $self->client->put(
        $self->api_url("lists/$address/members/$member"), [], $args);
    decode_response $res;
}

sub delete_list_member {
    my ($self, $address, $member) = @_;

    my $res = $self->client->delete(
        $self->api_url("lists/$address/members/$member"));
    decode_response $res;
}

1;
__END__

=encoding utf-8

=head1 NAME

WebService::Mailgun - API client for Mailgun (L<https://mailgun.com/>)

=head1 SYNOPSIS

    use WebService::Mailgun;

    my $mailgun = WebService::Mailgun->new(
        api_key => '<YOUR_API_KEY>',
        domain => '<YOUR_MAIL_DOMAIN>',
    );

    # send mail
    my $res = $mailgun->message({
        from    => 'foo@example.com',
        to      => 'bar@example.com',
        subject => 'test',
        text    => 'text',
    });

=head1 DESCRIPTION

WebService::Mailgun is API client for Mailgun (L<https://mailgun.com/>).

=head1 METHOD

=head2 new(api_key => $api_key, domain => $domain)

Create mailgun object.

=head2 message($args)

Send email message.

    # send mail
    my $res = $mailgun->message({
        from    => 'foo@example.com',
        to      => 'bar@example.com',
        subject => 'test',
        text    => 'text',
    });

L<https://documentation.mailgun.com/api-sending.html#sending>

=head2 lists()

Get list of mailing lists.

    # get mailing lists
    my $lists = $mailgun->lists();
    # => ArrayRef of mailing list object.

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 add_list($args)

Add mailing list.

    # add mailing list
    my $res = $mailgun->add_list({
        address => 'ml@example.com', # Mailing list address
        name    => 'ml sample',      # Mailing list name (Optional)
        description => 'sample',     # description (Optional)
        access_level => 'members',   # readonly(default), members, everyone
    });

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 list($address)

Get detail for mailing list.

    # get mailing list detail
    my $data = $mailgun->list('ml@exmaple.com');

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 update_list($address, $args)

Update mailing list detail.

    # update mailing list
    my $res = $mailgun->update_list('ml@example.com' => {
        address => 'ml@example.com', # Mailing list address (Optional)
        name    => 'ml sample',      # Mailing list name (Optional)
        description => 'sample',     # description (Optional)
        access_level => 'members',   # readonly(default), members, everyone
    });

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 delete_list($address)

Delete mailing list.

    # delete mailing list
    my $res = $mailgun->delete_list('ml@example.com');

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 list_members($address)

Get members for mailing list.

    # get members
    my $res = $mailgun->list_members('ml@example.com');

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 add_list_member($address, $args)

Add member for mailing list.

    # add member
    my $res = $mailgun->add_list_member('ml@example.com' => {
        address => 'user@example.com', # member address
        name    => 'username',         # member name (Optional)
        vars    => '{"age": 34}',      # member params(JSON string) (Optional)
        subscribed => 'yes',           # yes(default) or no
        upsert     => 'no',            # no (default). if yes, update exists member
    });

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 add_list_members($address, $args)

Adds multiple members for mailing list.

    use JSON::XS; # auto export 'encode_json'

    # add members
    my $res = $mailgun->add_list_members('ml@example.com' => {
        members => encode_json [
            { address => 'user1@example.com' },
            { address => 'user2@example.com' },
            { address => 'user3@example.com' },
        ],
        upsert  => 'no',            # no (default). if yes, update exists member
    });

    # too simple
    my $res = $mailgun->add_list_members('ml@example.com' => {
        members => encode_json [qw/user1@example.com user2@example.com/],
    });

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 list_member($address, $member_address)

Get member detail.

    # update member
    my $res = $mailgun->list_member('ml@example.com', 'user@example.com');

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 update_list_member($address, $member_address, $args)

Update member detail.

    # update member
    my $res = $mailgun->update_list_member('ml@example.com', 'user@example.com' => {
        address => 'user@example.com', # member address (Optional)
        name    => 'username',         # member name (Optional)
        vars    => '{"age": 34}',      # member params(JSON string) (Optional)
        subscribed => 'yes',           # yes(default) or no
    });

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head2 delete_list_members($address, $member_address)

Delete member for mailing list.

    # delete member
    my $res = $mailgun->delete_list_member('ml@example.com' => 'user@example.com');

L<https://documentation.mailgun.com/api-mailinglists.html#mailing-lists>

=head1 TODO

this API not implement yet.

=over

=item * L<Domains|https://documentation.mailgun.com/api-domains.html>

=item * L<Events|https://documentation.mailgun.com/api-events.html>

=item * L<Stats|https://documentation.mailgun.com/api-stats.html>

=item * L<Tags|https://documentation.mailgun.com/api-tags.html>

=item * L<Suppressions|https://documentation.mailgun.com/api-suppressions.html>

=item * L<Routes|https://documentation.mailgun.com/api-routes.html>

=item * L<Webhooks|https://documentation.mailgun.com/api-webhooks.html>

=item * L<Email Validation|https://documentation.mailgun.com/api-email-validation.html>

=back

=head1 SEE ALSO

L<WWW::Mailgun>, L<https://documentation.mailgun.com/>

=head1 LICENSE

Copyright (C) Kan Fushihara.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara@gmail.comE<gt>

=cut

