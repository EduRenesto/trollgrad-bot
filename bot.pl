#!/usr/bin/env perl

### 
#
# Trollgrad Bot
# by Edu and Cardu
#
# Esse script scrapeia o repositório de PDFs da PROGRAD, e checa se existem PDFs
# novos, por meio de um arquivo $DATE_FILE que guarda a unix timestamp da última
# checagem.
#
# Se houver, envia pro Telegram. Se não, só sai mesmo.
#
# DEPENDENCIAS:
# Esse script precisa de WWW::Telegram::BotAPI, Mojo::DOM e Date::Parse.
# Instale esses módulos pelo CPAN antes de rodar!
#
###

use strict;
use warnings;

use WWW::Telegram::BotAPI;
use Date::Parse;

# Perl just to mess up with Cardu

### Configuração
# $TOKEN: o Token que o @BotFather deu
my $TOKEN = $ENV{'TOKEN'} or die "Please set the TOKEN environment variable!";
# $URL: A URL dos PDFs da Prograd
my $URL = "http://prograd.ufabc.edu.br/pdf/?C=M;O=D";
# $DATE_FILE: onde salvaremos a última checagem. Coloque em algum lugar persistente,
# senão todos os PDFs serão enviados várias vezes, e isso não é legal.
my $DATE_FILE = $ENV{'DATE_FILE'} || "/tmp/trollgrad";

# Fetch everything
my $html = `curl --silent $URL`;

# Get the date file
my $last_update = `cat $DATE_FILE` || 1580089723;

print("Last update: $last_update\n");

# Load the DOM
my $dom = Mojo::DOM->new($html);

my $pdfs = $dom
    ->at("table")
    ->child_nodes
    ->grep(sub { $_ ne "\n"} )
    ->tail(-3)
    ->head(-1)
    ->map(sub {
        return {
            date => str2time($_->child_nodes->[2]->child_nodes->[0]->to_string),
            pdf => $_->child_nodes->[1]->child_nodes->[0]->attr('href')
        };
    })
    ->grep(sub {
        return $_->{date} >= $last_update;
    });

my $now = time();
`echo $now > $DATE_FILE`;

if($pdfs->size == 0) {
    print("No new PDFs!\n");
    exit(0);
}

# Let's start the bot!
my $bot = WWW::Telegram::BotAPI->new (
    token => $TOKEN
);

my $username = $bot->getMe->{result}{username};
print("Logged as $username\n");

$bot->sendMessage({
    chat_id => "\@trollgrad",
    text => "Opa opa! Temos PDFs fresquinhos!"
});

$pdfs->each(sub { 
    my $title = $_->{pdf};
    my $date = localtime($_->{date});
    $bot->sendMessage({
        chat_id => "\@trollgrad",
        text => "Postado $date: http://prograd.ufabc.edu.br/pdf/$title"
    });
    print("$_->{pdf}\n");
});

$bot->sendMessage({
    chat_id => "\@trollgrad",
    text => "Isso e tudo, pessoal!"
});
