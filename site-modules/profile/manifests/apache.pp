# @summary A short summary of the purpose of this class
#
# Configure Apache and install a default 
# Hello World website from a module
#
# @example
#   include profile::apache
class profile::apache {
    $docroot = '/var/www'
    $index_html = "${docroot}/index.html"
    $site_content = 'Hello world!'
    include apache
    apache::vhost { 'vhost.example.com':
      port    => 80,
      docroot => $docroot,
  }

  include pe_intro_hello_world::website
}
