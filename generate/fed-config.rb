#!/usr/bin/env ruby

require 'yaml'

def inline_cert(cert)
  IO.readlines(cert).map(&:strip).reject(&:empty?)[1 ... -1].join
end

if ARGV.size < 5
  puts "Usage: metadata-sources.rb rp_signing rp_encryption msa_signing msa_encryption output_dir"
  exit 1
end

rp_signing_cert = ARGV[0]
rp_encryption_cert = ARGV[1]
msa_signing_cert = ARGV[2]
msa_encryption_cert = ARGV[3]
output_dir = ARGV[4]

idps = {
  'headless-idp' => {},
  'stub-idp-one' => { 'enabled' => false },
  'stub-idp-two' => { 'useExactComparisonType' => false },
  'stub-idp-three' => {},
  'stub-idp-four' => {}
}

rps = {
  'test-rp.dev-rp' => {
    'simpleId' => 'test-rp',
    'matchingProcess' => { 'cycle3AttributeName' => 'NationalInsuranceNumber' },
  },
  'vsp.dev-rp' => {
    'entityId' => "http://localhost:50400/metadata",
    'metadataEnabled' => 'true',
    'simpleId' => 'test-rp',
    'matchingServiceEntityId' => 'http://localhost:3300/matching-service/SAML2/metadata',
    'matchingProcess' => { 'cycle3AttributeName' => 'NationalInsuranceNumber' },
    'assertionConsumerServices' => [
      { 'uri' => "http://#{ENV.fetch('EXTERNAL_HOST')}:3200/verify/response", 'index' => 0, 'isDefault' => true }
    ]
  },
}

matching_services = {
  'test-rp.dev-rp-ms' => {
    'uri' => "http://localhost:#{ENV.fetch('TEST_RP_MSA_PORT')}/matching-service/POST",
    'userAccountCreationUri' => "http://localhost:#{ENV.fetch('TEST_RP_MSA_PORT')}/unknown-user-attribute-query"
  },
  'vsp.dev-rp-ms' => {
    'entityId' => "http://localhost:3300/matching-service/SAML2/metadata",
    'uri' => "http://localhost:3300/matching-service/POST",
    'readMetadataFromEntityId' => "true"
  }
}

countries = {
  'stub-country' => { },
  # ensure that stub-idp in kubernetes is running locally before this script runs otherwise the metadata won't be cached
  # correctly by ./generate-eidas-metadata.rb in `verify-build`; see https://github.com/willp-bl/verify-kubernetes
  # there is a race condition as verify-kubernetes needs the pki generated during verify-local-startup for it to be
  # configured correctly so you might have to edit the countries/stub-country.yml file manually and re-run
  # ./generate-eidas-metadata.sh once everything is running using verify-build
  # 'stub-country' => { 'entityId' => "http://192.168.99.100:50140/stub-country/ServiceMetadata", },
  'stub-cef-reference' => { 'simpleId' => 'ZZ' },
  # these are disabled because they won't work (they aren't displayed by the frontend)
  'netherlands' => { 'simpleId' => 'NL', 'enabled' => 'false' },
  'spain' => { 'simpleId' => 'ES', 'enabled' => 'false' },
  'sweden' => { 'simpleId' => 'SE', 'enabled' => 'false' },
  'france' => { 'simpleId' => 'FR', 'enabled' => 'false' },
  'germany' => { 'simpleId' => 'DE', 'enabled' => 'false' },
}

Dir::mkdir(output_dir) unless Dir::exist?(output_dir)

Dir::chdir(output_dir) do
  ['idps', 'matching-services', 'transactions', 'countries'].each do |dir|
    Dir::mkdir(dir) unless Dir::exist?(dir)
  end

  Dir::chdir('idps') do
    idps.each do |idp, overrides|
      File.open("#{idp}.yml", 'w') do |f|
        f.write(YAML.dump({
            'entityId' => "http://#{idp}.local/SSO/POST",
            'simpleId' => idp,
            'enabled' => true,
            'supportedLevelsOfAssurance' => [ 'LEVEL_1', 'LEVEL_2' ],
            'useExactComparisonType' => true
          }.update(overrides)))
      end
    end
  end

  Dir::chdir('matching-services') do
    matching_services.each do |ms, overrides|
      File.open("#{ms}.yml", 'w') do |f|
        f.write(YAML.dump({
          'entityId' => "http://#{ms}.local/SAML2/MD",
          'healthCheckEnabled' => true,
          'signatureVerificationCertificates' => [ { 'x509' => inline_cert(msa_signing_cert) } ],
          'encryptionCertificate' => { 'x509' => inline_cert(msa_encryption_cert)
                                    }
                          }.update(overrides)))
      end
    end
  end

  Dir::chdir('transactions') do
    rps.each do |rp, overrides|
      File.open("#{rp}.yml", 'w') do |f|
        f.write(YAML.dump({
          'entityId' => "http://#{rp}.local/SAML2/MD",
          'simpleId' => rp,
          'assertionConsumerServices' => [
            { 'uri' => "http://#{ENV.fetch('EXTERNAL_HOST')}:50130/test-rp/login", 'index' => 0, 'isDefault' => true }
          ],
          'levelsOfAssurance' => [ 'LEVEL_2' ],
          'matchingServiceEntityId' => "http://#{rp}-ms.local/SAML2/MD",
          'displayName' => 'Register for an identity profile',
          'otherWaysDescription' => 'access Dev RP',
          'serviceHomepage' => "http://#{rp}.local/home",
          'rpName' => 'Dev RP',
          'analyticsTransactionDescription' => 'DEV RP',
          'enabled' => true,
          'eidasEnabled' => true,
          'shouldHubSignResponseMessages' => true,
          'userAccountCreationAttributes' => [
            'FIRST_NAME',
            'FIRST_NAME_VERIFIED',
            'MIDDLE_NAME',
            'MIDDLE_NAME_VERIFIED',
            'SURNAME',
            'SURNAME_VERIFIED',
            'DATE_OF_BIRTH',
            'DATE_OF_BIRTH_VERIFIED',
            'CURRENT_ADDRESS',
            'CURRENT_ADDRESS_VERIFIED'
          ],
          'otherWaysToCompleteTransaction' => 'Do something else',
          'signatureVerificationCertificates' => [ { 'x509' => inline_cert(rp_signing_cert) } ],
          'encryptionCertificate' => { 'x509' => inline_cert(rp_encryption_cert) }
        }.update(overrides)))
      end
    end
  end

  Dir::chdir('countries') do
    countries.each do |country, overrides|
      File.open("#{country}.yml", 'w') do |f|
        f.write(YAML.dump({
          'entityId' => "http://#{ENV.fetch('EXTERNAL_HOST')}:50140/#{country}/ServiceMetadata",
          'simpleId' => 'YY',
          'enabled' => true
        }.update(overrides)))
      end
    end
  end
end
