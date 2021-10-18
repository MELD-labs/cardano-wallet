require "bundler/setup"
require "cardano_wallet"
require "base64"
require_relative "../env"
require_relative "../helpers/utils"
require_relative "../helpers/matchers"

include Helpers::Utils

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end


# Helpers

##
# timeout in seconds for custom verifications
TIMEOUT = 180

##
# Intit cardano-wallet wrapper with timeout for getting the response back
CW = CardanoWallet.new({ timeout: TIMEOUT, port: ENV['WALLET_PORT'].to_i })
BYRON = CW.byron
SHELLEY = CW.shelley
SHARED = CW.shared
SETTINGS = CW.misc.settings
UTILS = CW.misc.utils
NETWORK = CW.misc.network
PROXY = CW.misc.proxy

##
# default passphrase for wallets
PASS = "Secure Passphrase"

##
# Artificial, non-existing id's
TXID = "1acf9c0f504746cbd102b49ffaf16dcafd14c0a2f1bbb23af265fbe0a04951cc"
SPID = "feea59bc6664572e631e9adfee77142cb51264156debf2e52970cc00"
SPID_BECH32 = "pool1v7g9ays8h668d74xjvln9xuh9adzh6xz0v0hvcd3xukpck5z56d"

# exemplary metadata
METADATA = { "0" => { "string" => "cardano" },
             "1" => { "int" => 14 },
             "2" => { "bytes" => "2512a00e9653fe49a44a5886202e24d77eeb998f" },
             "3" => { "list" => [ { "int" => 14 }, { "int" => 42 }, { "string" => "1337" } ] },
             "4" => { "map" => [ { "k" => { "string" => "key" }, "v" => { "string" => "value" } },
                             { "k" => { "int" => 14 }, "v" => { "int" => 42 } } ] } }

# Testnet assets with metadata from mock server https://metadata.cardano-testnet.iohkdev.io/
ASSETS = [ { "policy_id" => "ee1ce9d7560f48a4ba3867037dbec2d8fed776d94dd6b00a35309073",
             "asset_name" => "",
             "fingerprint" => "asset1s3yhz885gnyu2wcpz5h275u37hw3axz3c9sfqu",
             "metadata" => { "name" => "SadCoin",
                            "description" => "Coin with no asset name",
                            "url" => "https://sad.io",
                            "ticker" => "SAD",
                            "logo" => "iVBORw0KGgoAAAANSUhEUgAAABkAAAAeCAYAAADZ7LXbAAAACXBIWXMAAA7EAAAOxAGVKw4bAAACbUlEQVRIie3Vy0tUURzA8e855965c8lXUhlhEQVBSEmQRAURQbSIEqFl4N6/oHYtAhdtonatK8hVBCERZC+0jbZpIRVkIeagTJrO3Nd5tBhDMHOcGiHCA2dxHvDh9zs/fkc45xwbPORGA5tI/RFdGCL9MgAm/mNEVKuuaHA3OW+RlDb8zjt4O07VjFRPV8NBZC5PGMxj3/YQv7uGs7p+iJ5+ipgfIZr7hnWSXBjgT98iHr6IS+fqg7h0Dl8ZQpmQFKdJSmWkkuSj10TD3WCzv0f89m6S8BjWQehbVDpPWiojsASlEeLxG3WIJFtANneQei3EqpnMeWRxgtMahYGP/dhoqiry2+rKJh9i3l8l2KIRUlVQazDlRXTpOzIr43uQ7LlCvrO/9kjisT7Ehz6CBgtCki4sEC+ALpdQQUC+qQmXC3EO3NQAsHaP/QVx1mBnh5BKYpOYON2L6npJ/sw4svMRacmCc+TyOQwKGX/CRl9rQ4SQyPZeFqM27L7bhCcHUY37AVCtR7EtZ8EZhLN4vkIKhy1N1Ibo4ijq83UavAl04QmIFVekB1aDNQhnQFBZ14KABauRaFThHrrwbPmkPImYeQw6A5OBNRjnIxsPrIl4KzdUcwep9SFL8JVHNnqJeFcvyBCm7hJQBKPBZJWH334eGe5cE1m1hKM3l8nP3kcICVLiEEuXLfycQKpBnnhRtWmuWsLBkZtEucNYa8BkCJMiTFrJ/RLgHJjWc+vqyqsiMthGePo5SWsP2ohKWpamdZBqQbz1AvnjD6oCsI7/RM+8whTHljf8RrzWLlTLoXUB60LqMf6NP34T+T+RH/HOKLJ+ho1iAAAAAElFTkSuQmCC"
                            }
           },
           { "policy_id" => "919e8a1922aaa764b1d66407c6f62244e77081215f385b60a6209149",
             "asset_name" => "4861707079436f696e",
             "fingerprint" => "asset19mwamgpre24at3z34v2e5achszlhhqght9djqp",
             "metadata" => { "name" => "HappyCoin",
                            "description" => "Coin with asset name - and everyone is happy!!!",
                            "url" => "https://happy.io",
                            "decimals" => 6,
                            "ticker" => "HAPP",
                            "logo" => "iVBORw0KGgoAAAANSUhEUgAAABkAAAAeCAYAAADZ7LXbAAAACXBIWXMAAA7EAAAOxAGVKw4bAAACbUlEQVRIie3Vy0tUURzA8e855965c8lXUhlhEQVBSEmQRAURQbSIEqFl4N6/oHYtAhdtonatK8hVBCERZC+0jbZpIRVkIeagTJrO3Nd5tBhDMHOcGiHCA2dxHvDh9zs/fkc45xwbPORGA5tI/RFdGCL9MgAm/mNEVKuuaHA3OW+RlDb8zjt4O07VjFRPV8NBZC5PGMxj3/YQv7uGs7p+iJ5+ipgfIZr7hnWSXBjgT98iHr6IS+fqg7h0Dl8ZQpmQFKdJSmWkkuSj10TD3WCzv0f89m6S8BjWQehbVDpPWiojsASlEeLxG3WIJFtANneQei3EqpnMeWRxgtMahYGP/dhoqiry2+rKJh9i3l8l2KIRUlVQazDlRXTpOzIr43uQ7LlCvrO/9kjisT7Ehz6CBgtCki4sEC+ALpdQQUC+qQmXC3EO3NQAsHaP/QVx1mBnh5BKYpOYON2L6npJ/sw4svMRacmCc+TyOQwKGX/CRl9rQ4SQyPZeFqM27L7bhCcHUY37AVCtR7EtZ8EZhLN4vkIKhy1N1Ibo4ijq83UavAl04QmIFVekB1aDNQhnQFBZ14KABauRaFThHrrwbPmkPImYeQw6A5OBNRjnIxsPrIl4KzdUcwep9SFL8JVHNnqJeFcvyBCm7hJQBKPBZJWH334eGe5cE1m1hKM3l8nP3kcICVLiEEuXLfycQKpBnnhRtWmuWsLBkZtEucNYa8BkCJMiTFrJ/RLgHJjWc+vqyqsiMthGePo5SWsP2ohKWpamdZBqQbz1AvnjD6oCsI7/RM+8whTHljf8RrzWLlTLoXUB60LqMf6NP34T+T+RH/HOKLJ+ho1iAAAAAElFTkSuQmCC"
                            }
            },
         ]

def create_incomplete_shared_wallet(m, acc_ix, acc_xpub)
  script_template = { 'cosigners' =>
                        { 'cosigner#0' => acc_xpub },
                      'template' =>
                          { 'all' =>
                             [ 'cosigner#0',
                               'cosigner#1'
                             ]
                          }
                      }
  pscript = script_template
  dscript = script_template
  if (m.kind_of? Array)
    payload = { mnemonic_sentence: m,
                passphrase: PASS,
                name: "Shared wallet",
                account_index: acc_ix,
                payment_script_template: pscript,
                delegation_script_template: dscript,
                }
  else
    payload = { account_public_key: m,
                passphrase: PASS,
                name: "Shared wallet",
                account_index: acc_ix,
                payment_script_template: pscript,
                delegation_script_template: dscript
                }
  end

  SHARED.wallets.create(payload)['id']
end

def create_active_shared_wallet(m, acc_ix, acc_xpub)
  script_template = { 'cosigners' =>
                        { 'cosigner#0' => acc_xpub },
                      'template' =>
                          { 'all' =>
                             [ 'cosigner#0'
                             ]
                          }
                      }
  pscript = script_template
  dscript = script_template
  if (m.kind_of? Array)
    payload = { mnemonic_sentence: m,
                passphrase: PASS,
                name: "Shared wallet",
                account_index: acc_ix,
                payment_script_template: pscript,
                delegation_script_template: dscript,
                }
  else
    payload = { account_public_key: m,
                passphrase: PASS,
                name: "Shared wallet",
                account_index: acc_ix,
                payment_script_template: pscript,
                delegation_script_template: dscript
                }
  end

  SHARED.wallets.create(payload)['id']
end

def wait_for_shared_wallet_to_sync(wid)
  puts "Syncing Shared wallet..."
  retry_count = 10
  begin
    while (SHARED.wallets.get(wid)['state']['status'] == "syncing") do
      w = SHARED.wallets.get(wid)
      puts "  Syncing... #{w['state']['progress']['quantity']}%" if w['state']['progress']
      sleep 5
    end
  rescue NoMethodError
    puts "Retry #{retry_count}"
    retry_count -= 1
    puts "SHARED.wallets.get(#{wid}) returned:"
    puts SHARED.wallets.get(wid)
    retry if retry_count > 0
  end
end

def wait_for_all_shared_wallets(wids)
  wids.each do |w|
    wait_for_shared_wallet_to_sync(w)
  end
end

def create_shelley_wallet(name = "Wallet from mnemonic_sentence", mnemonic_sentence = mnemonic_sentence(24))
  SHELLEY.wallets.create({ name: name,
                          passphrase: PASS,
                          mnemonic_sentence: mnemonic_sentence
                         })['id']
end


def create_fixture_shelley_wallet
  SHELLEY.wallets.create({ name: "Fixture wallet with funds",
                          passphrase: PASS,
                          mnemonic_sentence: get_fixture_wallet_mnemonics("shelley")
                         })['id']
end

def wait_for_shelley_wallet_to_sync(wid)
  puts "Syncing Shelley wallet..."
  retry_count = 10
  begin
    while (SHELLEY.wallets.get(wid)['state']['status'] == "syncing") do
      w = SHELLEY.wallets.get(wid)
      puts "  Syncing... #{w['state']['progress']['quantity']}%" if w['state']['progress']
      sleep 5
    end
  rescue NoMethodError
    puts "Retry #{retry_count}"
    retry_count -= 1
    puts "SHELLEY.wallets.get(#{wid}) returned:"
    puts SHELLEY.wallets.get(wid)
    retry if retry_count > 0
  end
end

def wait_for_all_shelley_wallets(wids)
  wids.each do |w|
    wait_for_shelley_wallet_to_sync(w)
  end
end

def create_byron_wallet_with(mnem, style = "random", name = "Wallet from mnemonic_sentence")
  BYRON.wallets.create({ style: style,
                        name: name,
                        passphrase: PASS,
                        mnemonic_sentence: mnem
                       })['id']
end

def create_byron_wallet(style = "random", name = "Wallet from mnemonic_sentence")
  style == "random" ? mnem = mnemonic_sentence(12) : mnem = mnemonic_sentence(15)
  BYRON.wallets.create({ style: style,
                        name: name,
                        passphrase: PASS,
                        mnemonic_sentence: mnem
                       })['id']
end


def create_fixture_byron_wallet(style = "random")
  BYRON.wallets.create({ style: style,
                        name: "Fixture byron wallets with funds",
                        passphrase: PASS,
                        mnemonic_sentence: get_fixture_wallet_mnemonics(style)
                       })['id']
end

def wait_for_byron_wallet_to_sync(wid)
  puts "Syncing Byron wallet..."
  retry_count = 10
  begin
    while (BYRON.wallets.get(wid)['state']['status'] == "syncing") do
      w = BYRON.wallets.get(wid)
      puts "  Syncing... #{w['state']['progress']['quantity']}%" if w['state']['progress']
      sleep 5
    end
  rescue NoMethodError
    puts "Retry #{retry_count}"
    retry_count -= 1
    puts "BYRON.wallets.get(#{wid}) returned:"
    puts BYRON.wallets.get(wid)
    retry if retry_count > 0
  end
end

def wait_for_all_byron_wallets(wids)
  wids.each do |w|
    wait_for_byron_wallet_to_sync(w)
  end
end

##
# wait until action passed as &block returns true or TIMEOUT is reached
def eventually(label, &block)
  current_time = Time.now
  timeout_treshold = current_time + TIMEOUT
  while (block.call == false) && (current_time <= timeout_treshold) do
    sleep 5
    current_time = Time.now
  end
  if (current_time > timeout_treshold)
    fail "Action '#{label}' did not resolve within timeout: #{TIMEOUT}s"
  end
end

def teardown
  wb = BYRON.wallets
  wb.list.each do |w|
    wb.delete w['id']
  end

  ws = SHELLEY.wallets
  ws.list.each do |w|
    ws.delete w['id']
  end

  wsh = SHARED.wallets
  wsh.list.each do |w|
    wsh.delete w['id']
  end
end

##
# return asset total or available balance for comparison
def assets_balance(assets, received = 0)
  assets.map { |x| { "#{x['policy_id']}#{x['asset_name']}" => x['quantity'] + received } }.to_set
end

##
# return ada and asset accounts balance for shelley wallet
def get_shelley_balances(wid)
  w = SHELLEY.wallets.get(wid)
  total = w['balance']['total']['quantity']
  available = w['balance']['available']['quantity']
  reward = w['balance']['reward']['quantity']
  assets_total = w['assets']['total']
  assets_available = w['assets']['available']
  { 'total' => total,
   'available' => available,
   'rewards' => reward,
   'assets_available' => assets_available,
   'assets_total' => assets_total
  }
end
