## ######### PROJECT NAME : ##########
##
## Objet_Alerte.pm for storiq-objet-alerte
##
## ######### PROJECT DESCRIPTION : ###
##
## Objet de gestion des Alertes
##
## ###################################
##
## Made by Pujos Sylvain
## Login   <sylvain@intellique.com>
##
## ###################################
##

# Declaration du package Alert
package Objet_Alerte;

use strict;
use warnings;

use Objet_Conf;    # Objet de Conf Intellique
use Objet_Lang;    # Objet de langue

# Utilisation des packages fils
use Objet_Logger;

use Data::Dumper;

# Parametre lie au fichier de conf de alerte
my $full_path_conf = "/etc/storiq/alerte.conf";

sub new {

    # new($logger, [DEBUG]);
    my $alert = {};

    # Recuperation des parametres recu
    $alert->{OBJNAME} = shift;
    my $file = shift;

    $alert->{LOGGER} = shift;

    # Test de la présence du fichier.
    return ( 1, "file parameter is missing" ) if ( !defined($file) );

    # Si l'objet logger est absent, je le crée.
    if ( !$alert->{LOGGER} ) {
        $alert->{LOGGER} = new Objet_Logger();
        $alert->{LOGGER}->debug(
            "$alert->{OBJNAME} : new : Objet_Logger parameter was missing.");
    }

    # Verification de l'integrite de l'objet Logger recu
    unless ( ref( $alert->{LOGGER} ) eq "Objet_Logger" ) {
        $alert->{LOGGER} = new Objet_Logger();
        $alert->{LOGGER}->debug(
            "$alert->{OBJNAME} : new : Objet_Logger parameter wasn't an correct Objet_Logger."
        );
    }

    # Creation de l'objet de conf de l'objet alerte
    my ( $error, $conf ) =
        new Objet_Conf( $full_path_conf, $alert->{LOGGER} );

    # Verification de l'integrite du fichier deConf du pere recu
    if ($error) {
        $alert->{LOGGER}->error(
            "$alert->{OBJNAME} : new : Unable to instanciate Objet_Conf : $conf"
        );
        return ( 1, "Unable to instanciate Objet_Conf : $conf" );
    }

    ( $error, %{ $alert->{CONF} } ) = $conf->get_all();

    # Instanciation de l'objet de langue
    my $tmp_ref;
    ( $error, $tmp_ref ) = new Objet_Lang( $file, $alert->{LOGGER} );
    if ($error) {
        $alert->{LOGGER}->error(
            "$alert->{OBJNAME} : new : Unable to instanciate Objet_Lang : $tmp_ref"
        );
        return ( 1, "Unable to instanciate Objet_Lang : $tmp_ref" );
    }
    $alert->{OBJLANG} = $tmp_ref;

    $alert->{LOGGER}->debug("new : Creation d' Objet_Alerte");

    bless($alert);
    return ( 0, $alert );
}

sub send {

    #send(\@message_mail, \@message_snmp);
    my $self     = shift;
    my $ref_mail = shift;
    my $ref_snmp = shift;

    my @messages;

    # Parcours des actions en fonction du niveau d alerte souhaite
    foreach ( keys( %{ $self->{CONF} } ) ) {

        # Si la cle est defaut, on zappe
        next if ( $_ eq "DEFAUTINTELLIQUEUNIQUE" );

        # Si la cle n'est pas à yes, on zappe
        next if ( $self->{CONF}{$_}{'alerte'} ne "yes" );

        if ( $_ eq "MAIL" and $ref_mail ) {
            my ( $error, $msg ) = send_mail( $self, @{$ref_mail} );
            return ( $error, $msg ) if ($error);
            push @messages, $msg;
        }
        if ( $_ eq "SNMP" and $ref_snmp ) {
            my ( $error, $msg ) = send_snmp( $self, @{$ref_snmp} );
            return ( $error, $msg ) if ($error);
            push @messages, $msg;
        }
    }

    return 0, \@messages;
}

sub send_mail {

    # send_mail();
    # Creation et envoie de mail
    my $self      = shift;
    my @ref_sujet = @{ shift @_ };
    my @ref_msg   = @{ shift @_ };

    # Verification de la presence du serveur smtp
    unless ( $self->{CONF}{'MAIL'}{'smtp'} ) {
        $self->{LOGGER}->error(
            "Objet_Alerte : send_mail : Smtp server address is missing");
        return ( 1, "Smtp server address is missing" );
    }

    # Verification de la presence du destinataire
    unless ( $self->{CONF}{'MAIL'}{'destinataire'} ) {
        $self->{LOGGER}->error(
            "Objet_Alerte : send_mail : Recipient address is missing");
        return ( 1, "Recipient address is missing" );
    }

    # Verification de la presence de lexpediteur
    unless ( $self->{CONF}{'MAIL'}{'expediteur'} ) {
        $self->{LOGGER}
            ->error("Objet_Alerte : send_mail : Sender address is missing");
        return ( 1, "Sender address is missing" );
    }

    #Recuperation d'un message
    my ( $err_sujet, $sujet ) =
        $self->{OBJLANG}
        ->get_msg_with_section( shift @ref_sujet, "MAIL", @ref_sujet );
    my ( $err_msg, $message ) =
        $self->{OBJLANG}
        ->get_msg_with_section( shift @ref_msg, "MAIL", @ref_msg );
    $sujet   =~ s/\\n/\n/g;
    $message =~ s/\\n/\n/g;

    $self->{LOGGER}
        ->warn("Objet_Alerte : send_mail : Unable to get subect : $sujet")
        if ($err_sujet);
    $self->{LOGGER}
        ->warn("Objet_Alerte : send_mail : Unable to get message : $message")
        if ($err_msg);

    my ( $error, $msg ) = $self->{LOGGER}->configure_mail(
        $self->{CONF}{'MAIL'}{'smtp'},
        $self->{CONF}{'MAIL'}{'expediteur'},
        $self->{CONF}{'MAIL'}{'destinataire'}
    );

    if ($error) {
        $self->{LOGGER}->error(
            "Objet_Alerte : send_mail : Unable to configure mail alerte : $msg"
        );
        return ( 1, "Unable to configure mail alerte : $msg" );
    }

    ( $error, $msg ) = $self->{LOGGER}->mail( $sujet, $message );
    $self->{LOGGER}->debug( $sujet . "  " . $message );
    if ($error) {
        $self->{LOGGER}->error(
            "Objet_Alerte : send_mail : Unable to send alert mail : $msg");
        return ( 1, "Unable to send alert mail : $msg" );
    }

    return ( 0, "Mail sent" );
}

## ###################################
## Methode d'envoi de trappes snmp
sub send_snmp {
    my $self = shift;

    my $oid      = shift;
    my $oid_type = shift;
    my $spe_trap = shift;

    my $key_lang = shift;
    my @ref      = @_;

    unless ( $self->{CONF}{'SNMP'}{'host_manager'} ) {
        $self->{LOGGER}
            ->error("Objet_Alerte : send_snmp : Host_manager is missing");
        return ( 1, "Host_manager is missing" );
    }

    unless ( $self->{CONF}{'SNMP'}{'udp_port'} ) {
        $self->{LOGGER}
            ->error("Objet_Alerte : send_snmp : Udp port is missing");
        return ( 1, "Udp port is missing" );
    }

    unless ( $self->{CONF}{'SNMP'}{'community'} ) {
        $self->{LOGGER}
            ->error("Objet_Alerte : send_snmp : Community is missing");
        return ( 1, "Community is smissing" );
    }

    unless ( $self->{CONF}{'SNMP'}{'version_snmp'} ) {
        $self->{LOGGER}
            ->error("Objet_Alerte : send_snmp : Version_snmp is missing");
        return ( 1, "Version snmp is missng" );
    }

    unless ( $self->{CONF}{'SNMP'}{'OID_enterprise'} ) {
        $self->{LOGGER}
            ->error("Objet_Alerte : send_snmp : OID_enterprise is missing");
        return ( 1, "OID_entreprise is missing" );
    }

    #Recuperation d'un message
    my ( $err_msg, $message ) =
        $self->{OBJLANG}->get_msg_with_section( $key_lang, "SNMP", @ref );
    $self->{LOGGER}
        ->warn("Objet_Alerte : send_snmp : Unable to get message : $message")
        if ($err_msg);

    my ( $error, $ret ) = $self->{LOGGER}->configure_snmp(
        $self->{CONF}{'SNMP'}{'host_manager'},
        $self->{CONF}{'SNMP'}{'udp_port'},
        $self->{CONF}{'SNMP'}{'community'},
        $self->{CONF}{'SNMP'}{'version_snmp'},
        $self->{CONF}{'SNMP'}{'OID_enterprise'}
    );

    if ($error) {
        $self->{LOGGER}->error(
            "Objet_Alerte : send_snmp : Unable to configure snmp : $ret");
        return ( 1, "Unable to configure snmp : $ret" );
    }

    ( $error, $ret ) =
        $self->{LOGGER}->snmp( $message, $oid, $oid_type, $spe_trap );
    $self->{LOGGER}->debug($message);
    if ($error) {
        $self->{LOGGER}->error(
            "Objet_Alerte : send_snmp : Unable to send snmp trap : $ret");
        return ( 1, "Unable to send snmp trap : $ret" );
    }

    return ( 0, "Snmp trap sent" );
}

1;
