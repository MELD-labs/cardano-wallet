RSpec.describe "Cardano Wallet E2E tests", :e2e => true do

  before(:all) do
    # shelley tests
    @wid = create_fixture_shelley_wallet
    @target_id = create_shelley_wallet("Target tx wallet")
    @target_id_assets = create_shelley_wallet("Target asset tx wallet")
    @target_id_withdrawal = create_shelley_wallet("Target tx withdrawal wallet")
    @target_id_meta = create_shelley_wallet("Target tx metadata wallet")
    @target_id_ttl = create_shelley_wallet("Target tx ttl wallet")
    @target_id_pools = create_shelley_wallet("Target tx pool join/quit wallet")

    # byron tests
    @wid_rnd = create_fixture_byron_wallet "random"
    @wid_ic = create_fixture_byron_wallet "icarus"
    @target_id_rnd = create_shelley_wallet("Target tx wallet")
    @target_id_ic = create_shelley_wallet("Target tx wallet")
    @target_id_rnd_assets = create_shelley_wallet("Target asset tx wallet")
    @target_id_ic_assets = create_shelley_wallet("Target asset tx wallet")

    # shared tests
    @wid_sha = create_active_shared_wallet(mnemonic_sentence(24), '0H', 'self')

    @nightly_shared_wallets = [ @wid_sha ]
    @nighly_byron_wallets = [ @wid_rnd, @wid_ic ]
    @nightly_shelley_wallets = [
                                  @wid,
                                  @target_id,
                                  @target_id_assets,
                                  @target_id_withdrawal,
                                  @target_id_meta,
                                  @target_id_ttl,
                                  @target_id_rnd,
                                  @target_id_ic,
                                  @target_id_rnd_assets,
                                  @target_id_ic_assets,
                                  @target_id_pools
                                ]
    wait_for_all_byron_wallets(@nighly_byron_wallets)
    wait_for_all_shelley_wallets(@nightly_shelley_wallets)
    wait_for_all_shared_wallets(@nightly_shared_wallets)

    # @wid_rnd = "94c0af1034914f4455b7eb795ebea74392deafe9"
    # @wid_ic = "a468e96ab85ad2043e48cf2e5f3437b4356769f4"
    # @wid = "1f82e83772b7579fc0854bd13db6a9cce21ccd95"
    # @target_id = "79f76c99c2b98d4a37d6600c9fbcc07076a4ea50"
  end

  after(:all) do
    @nighly_byron_wallets.each do |wid|
      BYRON.wallets.delete wid
    end
    @nightly_shelley_wallets.each do |wid|
      SHELLEY.wallets.delete wid
    end
    @nightly_shared_wallets.each do |wid|
      SHARED.wallets.delete wid
    end
  end

  describe "E2E Construct -> Sign -> Submit" do
    it "Single output transaction" do
      skip "ADP-1202 - fee is miscalculated"

      amt = 1000000

      address = SHELLEY.addresses.list(@target_id)[0]['id']
      target_before = get_shelley_balances(@target_id)
      src_before = get_shelley_balances(@wid)

      payment = [{ :address => address,
                 :amount => { :quantity => amt,
                           :unit => 'lovelace' }
               }]
      tx_constructed = SHELLEY.transactions.construct(@wid, payment)
      expect(tx_constructed).to be_correct_and_respond 202
      expected_fee = tx_constructed['fee']['quantity']

      tx_signed = SHELLEY.transactions.sign(@wid, PASS, tx_constructed['transaction'])
      expect(tx_signed).to be_correct_and_respond 202

      tx_submitted = PROXY.submit_external_transaction(Base64.decode64(tx_signed['transaction']))
      expect(tx_submitted).to be_correct_and_respond 202
      tx_id = tx_submitted['id']

      eventually "Tx is in ledger" do
        tx = SHELLEY.transactions.get(@wid, tx_id)
        tx.code == 200 && tx['status'] == 'in_ledger'
      end

      target_after = get_shelley_balances(@target_id)
      src_after = get_shelley_balances(@wid)
      tx = SHELLEY.transactions.get(@wid, tx_id)
      # verify actual fee the same as constructed
      expect(expected_fee).to eq tx['fee']['quantity']

      # verify balances are correct on target wallet
      expect(target_after['available']).to eq (amt + target_before['available'])
      expect(target_after['total']).to eq (amt + target_before['total'])
      expect(target_after['reward']).to eq (target_before['reward'])

      # verify balances are correct on src wallet
      expect(src_after['available']).to eq (src_before['available'] - amt - expected_fee)
      expect(src_after['total']).to eq (src_before['total'] - amt - expected_fee)
      expect(src_after['reward']).to eq (src_before['reward'])
    end

    it "Multi output transaction" do
      skip "ADP-1202 - fee is miscalculated"

      amt = 1000000

      address = SHELLEY.addresses.list(@target_id)[0]['id']
      target_before = get_shelley_balances(@target_id)
      src_before = get_shelley_balances(@wid)

      payment = [{ :address => address,
                 :amount => { :quantity => amt,
                           :unit => 'lovelace' }
                },
                { :address => address,
                 :amount => { :quantity => amt,
                             :unit => 'lovelace' }
                }
                ]
      tx_constructed = SHELLEY.transactions.construct(@wid, payment)
      expect(tx_constructed).to be_correct_and_respond 202
      expected_fee = tx_constructed['fee']['quantity']

      tx_signed = SHELLEY.transactions.sign(@wid, PASS, tx_constructed['transaction'])
      expect(tx_signed).to be_correct_and_respond 202

      tx_submitted = PROXY.submit_external_transaction(Base64.decode64(tx_signed['transaction']))
      expect(tx_submitted).to be_correct_and_respond 202
      tx_id = tx_submitted['id']

      eventually "Tx is in ledger" do
        tx = SHELLEY.transactions.get(@wid, tx_id)
        tx.code == 200 && tx['status'] == 'in_ledger'
      end

      target_after = get_shelley_balances(@target_id)
      src_after = get_shelley_balances(@wid)
      tx = SHELLEY.transactions.get(@wid, tx_id)
      # verify actual fee the same as constructed
      expect(expected_fee).to eq tx['fee']['quantity']

      # verify balances are correct on target wallet
      expect(target_after['available']).to eq (2 * amt + target_before['available'])
      expect(target_after['total']).to eq (2 * amt + target_before['total'])
      expect(target_after['reward']).to eq (target_before['reward'])

      # verify balances are correct on src wallet
      expect(src_after['available']).to eq (src_before['available'] - 2 * amt - expected_fee)
      expect(src_after['total']).to eq (src_before['total'] - 2 * amt - expected_fee)
      expect(src_after['reward']).to eq (src_before['reward'])
    end

    it "Multi-assets transaction" do
      skip "ADP-1202 - fee is miscalculated"

      amt = 1
      amt_ada = 1600000
      address = SHELLEY.addresses.list(@target_id)[1]['id']
      target_before = get_shelley_balances(@target_id)
      src_before = get_shelley_balances(@wid)

      payment = [{ "address" => address,
                  "amount" => { "quantity" => amt_ada, "unit" => "lovelace" },
                  "assets" => [ { "policy_id" => ASSETS[0]["policy_id"],
                                  "asset_name" => ASSETS[0]["asset_name"],
                                  "quantity" => amt
                                },
                                { "policy_id" => ASSETS[1]["policy_id"],
                                  "asset_name" => ASSETS[1]["asset_name"],
                                  "quantity" => amt
                                }
                              ]
                  }
                 ]

      tx_constructed = SHELLEY.transactions.construct(@wid, payment)
      expect(tx_constructed).to be_correct_and_respond 202
      expected_fee = tx_constructed['fee']['quantity']

      tx_signed = SHELLEY.transactions.sign(@wid, PASS, tx_constructed['transaction'])
      expect(tx_signed).to be_correct_and_respond 202

      tx_submitted = PROXY.submit_external_transaction(Base64.decode64(tx_signed['transaction']))
      expect(tx_submitted).to be_correct_and_respond 202
      tx_id = tx_submitted['id']

      eventually "Tx is in ledger" do
        tx = SHELLEY.transactions.get(@wid, tx_id)
        tx.code == 200 && tx['status'] == 'in_ledger'
      end

      target_after = get_shelley_balances(@target_id)
      src_after = get_shelley_balances(@wid)
      tx = SHELLEY.transactions.get(@wid, tx_id)
      # verify actual fee the same as constructed
      expect(expected_fee).to eq tx['fee']['quantity']

      # verify balances are correct on target wallet
      if target_before['assets_total'] == []
        target_balance = [{ "#{ASSETS[0]["policy_id"]}#{ASSETS[0]["asset_name"]}" => amt },
                          { "#{ASSETS[1]["policy_id"]}#{ASSETS[1]["asset_name"]}" => amt }].to_set
        expect(assets_balance(target_after['assets_total'])).to eq target_balance
        expect(assets_balance(target_after['assets_available'])).to eq target_balance
      else
        expect(assets_balance(target_after['assets_total'])).to eq assets_balance(target_before['assets_total'], (+amt))
        expect(assets_balance(target_after['assets_available'])).to eq assets_balance(target_before['assets_available'], (+amt))
      end
      expect(target_after['available']).to eq (amt_ada + target_before['available'])
      expect(target_after['total']).to eq (amt_ada + target_before['total'])

      # verify balances are correct on src wallet
      expect(assets_balance(src_after['assets_total'])).to eq assets_balance(src_before['assets_total'], (-amt))
      expect(assets_balance(src_after['assets_available'])).to eq assets_balance(src_before['assets_available'], (-amt))
      expect(src_after['total']).to eq (src_before['total'] - amt_ada - expected_fee)
      expect(src_after['available']).to eq (src_before['available'] - amt_ada - expected_fee)
    end

    it "Only withdrawal" do
      skip "ADP-1202 - fee is miscalculated"

      balance = get_shelley_balances(@wid)
      tx_constructed = SHELLEY.transactions.construct(@wid,
                                                      payments = nil,
                                                      withdrawal = 'self')
      expect(tx_constructed).to be_correct_and_respond 202
      withdrawal = tx_constructed['coin_selection']['withdrawals'].map { |x| x['amount']['quantity'] }.first
      expect(withdrawal).to eq 0
      expected_fee = tx_constructed['fee']['quantity']

      tx_signed = SHELLEY.transactions.sign(@wid, PASS, tx_constructed['transaction'])
      expect(tx_signed).to be_correct_and_respond 202

      tx_submitted = PROXY.submit_external_transaction(Base64.decode64(tx_signed['transaction']))
      expect(tx_submitted).to be_correct_and_respond 202
      tx_id = tx_submitted['id']

      eventually "Tx is in ledger" do
        tx = SHELLEY.transactions.get(@wid, tx_id)
        tx.code == 200 && tx['status'] == 'in_ledger'
      end
      new_balance = get_shelley_balances(@wid)
      tx = SHELLEY.transactions.get(@wid, tx_id)

      # verify actual fee the same as constructed
      expect(expected_fee).to eq tx['fee']['quantity']

      # verify balance is as expected
      expect(new_balance['available']).to eq (balance['available'] - expected_fee)
      expect(new_balance['total']).to eq (balance['total'] - expected_fee)
    end

    it "Only metadata" do
      skip "ADP-1202 - fee is miscalculated"

      metadata = METADATA
      balance = get_shelley_balances(@wid)
      tx_constructed = SHELLEY.transactions.construct(@wid,
                                                      payments = nil,
                                                      withdrawal = nil,
                                                      metadata)
      expect(tx_constructed).to be_correct_and_respond 202
      expected_fee = tx_constructed['fee']['quantity']

      tx_signed = SHELLEY.transactions.sign(@wid, PASS, tx_constructed['transaction'])
      expect(tx_signed).to be_correct_and_respond 202

      tx_submitted = PROXY.submit_external_transaction(Base64.decode64(tx_signed['transaction']))
      expect(tx_submitted).to be_correct_and_respond 202
      tx_id = tx_submitted['id']

      eventually "Tx is in ledger and has metadata" do
        tx = SHELLEY.transactions.get(@wid, tx_id)
        tx.code == 200 && tx['status'] == 'in_ledger' && tx['metadata'] == metadata
      end
      new_balance = get_shelley_balances(@wid)
      tx = SHELLEY.transactions.get(@wid, tx_id)
      # verify actual fee the same as constructed
      expect(expected_fee).to eq tx['fee']['quantity']

      # verify balance is as expected
      expect(new_balance['available']).to eq (balance['available'] - expected_fee)
      expect(new_balance['total']).to eq (balance['total'] - expected_fee)
    end

    it "Delegation" do
      pending "ADP-1189 - Deposit is empty, delegation not working"
      balance = get_shelley_balances(@wid)
      pool_id = SHELLEY.stake_pools.list({ stake: 1000 })[0]['id']
      delegation = [{
                      "join" => {
                                  "pool" => pool_id,
                                  "stake_key_index" => "1852H"
                                }
                    }]
      tx_constructed = SHELLEY.transactions.construct(@wid,
                                                      payments = nil,
                                                      withdrawal = nil,
                                                      metadata = nil,
                                                      delegation)
      expect(tx_constructed).to be_correct_and_respond 202
      deposit = tx_constructed['coin_selection']['deposits']
      expect(deposit).not_to eq []
      expected_fee = tx_constructed['fee']['quantity']

      tx_signed = SHELLEY.transactions.sign(@wid, PASS, tx_constructed['transaction'])
      expect(tx_signed).to be_correct_and_respond 202

      tx_submitted = PROXY.submit_external_transaction(Base64.decode64(tx_signed['transaction']))
      expect(tx_submitted).to be_correct_and_respond 202
      tx_id = tx_submitted['id']

      eventually "Tx is in ledger" do
        tx = SHELLEY.transactions.get(@wid, tx_id)
        tx.code == 200 && tx['status'] == 'in_ledger'
      end
      new_balance = get_shelley_balances(@wid)
      tx = SHELLEY.transactions.get(@wid, tx_id)
      # verify actual fee the same as constructed
      expect(expected_fee).to eq tx['fee']['quantity']

      # TODO: enable when unpending this tc
      # expect(new_balance['available']).to eq (balance['available'] - deposit - expected_fee)
      # expect(new_balance['total']).to eq (balance['total'] - deposit - expected_fee)
    end
  end

  describe "E2E Shared" do
    it "I can receive transaction to shared wallet" do
      asset_quantity = 1
      ada_amt = 3000000
      address = SHARED.addresses.list(@wid_sha)[1]['id']
      payload = [{ "address" => address,
                  "amount" => { "quantity" => ada_amt, "unit" => "lovelace" },
                  "assets" => [ { "policy_id" => ASSETS[0]["policy_id"],
                                  "asset_name" => ASSETS[0]["asset_name"],
                                  "quantity" => asset_quantity
                                },
                                { "policy_id" => ASSETS[1]["policy_id"],
                                  "asset_name" => ASSETS[1]["asset_name"],
                                  "quantity" => asset_quantity
                                }
                              ]
                  }
                 ]

      tx_sent = SHELLEY.transactions.create(@wid, PASS, payload)

      expect(tx_sent).to be_correct_and_respond 202
      expect(tx_sent.to_s).to include "pending"

      eventually "Assets are on target shared wallet: #{@wid_sha}" do
        first = ASSETS[0]["policy_id"] + ASSETS[0]["asset_name"]
        second = ASSETS[1]["policy_id"] + ASSETS[1]["asset_name"]
        shared_wallet = SHARED.wallets.get(@wid_sha)
        total_assets = shared_wallet['assets']['total']
        available_assets = shared_wallet['assets']['available']
        total_ada = shared_wallet['balance']['total']['quantity']
        available_ada = shared_wallet['balance']['available']['quantity']
        total = Hash.new
        available = Hash.new

        unless total_assets.empty?
          total[first] = total_assets.select { |a| a['policy_id'] == ASSETS[0]["policy_id"] && a['asset_name'] == ASSETS[0]["asset_name"] }.first["quantity"]
          total[second] = total_assets.select { |a| a['policy_id'] == ASSETS[1]["policy_id"] && a['asset_name'] == ASSETS[1]["asset_name"] }.first["quantity"]
        end

        unless available_assets.empty?
          available[first] = available_assets.select { |a| a['policy_id'] == ASSETS[0]["policy_id"] && a['asset_name'] == ASSETS[0]["asset_name"] }.first["quantity"]
          available[second] = available_assets.select { |a| a['policy_id'] == ASSETS[1]["policy_id"] && a['asset_name'] == ASSETS[1]["asset_name"] }.first["quantity"]
        end

        (total[first] == asset_quantity) && (total[second] == asset_quantity) &&
        (available[first] == asset_quantity) && (available[second] == asset_quantity) &&
        (available_ada == ada_amt) && (total_ada == ada_amt)
      end
    end
  end

  describe "E2E Shelley" do
    describe "Native Assets" do
      it "I can list native assets" do
        assets = SHELLEY.assets.get @wid
        expect(assets).to be_correct_and_respond 200
        expect(assets.to_s).to include ASSETS[0]["policy_id"]
        expect(assets.to_s).to include ASSETS[0]["asset_name"]
        expect(assets.to_s).to include ASSETS[0]["metadata"]["name"]
        expect(assets.to_s).to include ASSETS[1]["policy_id"]
        expect(assets.to_s).to include ASSETS[1]["asset_name"]
        expect(assets.to_s).to include ASSETS[1]["metadata"]["name"]
      end

      it "I can get native assets by policy_id" do
        assets = SHELLEY.assets.get(@wid, policy_id = ASSETS[0]["policy_id"])
        expect(assets).to be_correct_and_respond 200
        expect(assets["policy_id"]).to eq ASSETS[0]["policy_id"]
        expect(assets["asset_name"]).to eq ASSETS[0]["asset_name"]
        expect(assets["metadata"]).to eq ASSETS[0]["metadata"]
        expect(assets["asset_name"]).not_to eq ASSETS[1]["asset_name"]
        expect(assets["metadata"]).not_to eq ASSETS[1]["metadata"]
      end

      it "I can get native assets by policy_id and asset_name" do
        assets = SHELLEY.assets.get(@wid, policy_id = ASSETS[1]["policy_id"], asset_name = ASSETS[1]["asset_name"])
        expect(assets).to be_correct_and_respond 200
        expect(assets["policy_id"]).to eq ASSETS[1]["policy_id"]
        expect(assets["asset_name"]).to eq ASSETS[1]["asset_name"]
        expect(assets["metadata"]).to eq ASSETS[1]["metadata"]
        expect(assets["asset_name"]).not_to eq ASSETS[0]["asset_name"]
        expect(assets["metadata"]).not_to eq ASSETS[0]["metadata"]["name"]
      end

      it "I can send native assets tx and they are received" do
        asset_quantity = 1
        address = SHELLEY.addresses.list(@target_id_assets)[1]['id']
        payload = [{ "address" => address,
                    "amount" => { "quantity" => 0, "unit" => "lovelace" },
                    "assets" => [ { "policy_id" => ASSETS[0]["policy_id"],
                                    "asset_name" => ASSETS[0]["asset_name"],
                                    "quantity" => asset_quantity
                                  },
                                  { "policy_id" => ASSETS[1]["policy_id"],
                                    "asset_name" => ASSETS[1]["asset_name"],
                                    "quantity" => asset_quantity
                                  }
                                ]
                    }
                   ]

        tx_sent = SHELLEY.transactions.create(@wid, PASS, payload)

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "Assets are on target wallet: #{@target_id_assets}" do
          first = ASSETS[0]["policy_id"] + ASSETS[0]["asset_name"]
          second = ASSETS[1]["policy_id"] + ASSETS[1]["asset_name"]
          total_assets = SHELLEY.wallets.get(@target_id_assets)['assets']['total']
          available_assets = SHELLEY.wallets.get(@target_id_assets)['assets']['available']
          total = Hash.new
          available = Hash.new

          unless total_assets.empty?
            total[first] = total_assets.select { |a| a['policy_id'] == ASSETS[0]["policy_id"] && a['asset_name'] == ASSETS[0]["asset_name"] }.first["quantity"]
            total[second] = total_assets.select { |a| a['policy_id'] == ASSETS[1]["policy_id"] && a['asset_name'] == ASSETS[1]["asset_name"] }.first["quantity"]
          end

          unless available_assets.empty?
            available[first] = available_assets.select { |a| a['policy_id'] == ASSETS[0]["policy_id"] && a['asset_name'] == ASSETS[0]["asset_name"] }.first["quantity"]
            available[second] = available_assets.select { |a| a['policy_id'] == ASSETS[1]["policy_id"] && a['asset_name'] == ASSETS[1]["asset_name"] }.first["quantity"]
          end

          (total[first] == asset_quantity) && (total[second] == asset_quantity) &&
          (available[first] == asset_quantity) && (available[second] == asset_quantity)
        end
      end

    end

    describe "Shelley Migrations" do
      it "I can create migration plan shelley -> shelley" do
        target_id = create_shelley_wallet
        addrs = SHELLEY.addresses.list(target_id).map { |a| a['id'] }

        plan = SHELLEY.migrations.plan(@wid, addrs)
        expect(plan).to be_correct_and_respond 202
        expect(plan['balance_selected']['assets']).not_to be []
        expect(plan['balance_leftover']).to eq ({ "ada" => { "quantity" => 0,
                                                         "unit" => "lovelace" },
                                                 "assets" => [] })
      end
    end

    describe "Shelley Transactions" do
      it "I can send transaction and funds are received" do
        amt = 1000000

        address = SHELLEY.addresses.list(@target_id)[0]['id']
        available_before = SHELLEY.wallets.get(@target_id)['balance']['available']['quantity']
        total_before = SHELLEY.wallets.get(@target_id)['balance']['total']['quantity']

        tx_sent = SHELLEY.transactions.create(@wid, PASS, [{ address => amt }])

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "Funds are on target wallet: #{@target_id}" do
          available = SHELLEY.wallets.get(@target_id)['balance']['available']['quantity']
          total = SHELLEY.wallets.get(@target_id)['balance']['total']['quantity']
          (available == amt + available_before) && (total == amt + total_before)
        end
      end

      it "I can send transaction with ttl and funds are received" do
        amt = 1000000
        ttl_in_s = 120

        address = SHELLEY.addresses.list(@target_id_ttl)[0]['id']
        tx_sent = SHELLEY.transactions.create(@wid,
                                              PASS,
                                              [{ address => amt }],
                                              withdrawal = nil,
                                              metadata = nil,
                                              ttl_in_s)

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "Funds are on target wallet: #{@target_id}" do
          available = SHELLEY.wallets.get(@target_id_ttl)['balance']['available']['quantity']
          total = SHELLEY.wallets.get(@target_id_ttl)['balance']['total']['quantity']
          (available == amt) && (total == amt)
        end
      end

      it "Transaction with ttl = 0 would expire and I can forget it" do
        skip "Test is flaky due to ADP-608"
        amt = 1000000
        ttl_in_s = 0

        address = SHELLEY.addresses.list(@target_id_ttl)[0]['id']
        tx_sent = SHELLEY.transactions.create(@wid,
                                              PASS,
                                              [{ address => amt }],
                                              withdrawal = nil,
                                              metadata = nil,
                                              ttl_in_s)

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "TX `#{tx_sent['id']}' expires on `#{@wid}'" do
          SHELLEY.transactions.get(@wid, tx_sent['id'])['status'] == 'expired'
        end

        res = SHELLEY.transactions.forget(@wid, tx_sent['id'])
        expect(res).to be_correct_and_respond 204

        fres = SHELLEY.transactions.get(@wid, tx_sent['id'])
        expect(fres).to be_correct_and_respond 404
      end

      it "I can send transaction using 'withdrawal' flag and funds are received" do
        amt = 1000000
        address = SHELLEY.addresses.list(@target_id_withdrawal)[0]['id']

        tx_sent = SHELLEY.transactions.create(@wid, PASS, [{ address => amt }], 'self')

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "Funds are on target wallet: #{@target_id_withdrawal}" do
          available = SHELLEY.wallets.get(@target_id_withdrawal)['balance']['available']['quantity']
          total = SHELLEY.wallets.get(@target_id_withdrawal)['balance']['total']['quantity']
          (available == amt) && (total == amt)
        end
      end

      it "I can send transaction with metadata" do
        amt = 1000000
        metadata = METADATA

        address = SHELLEY.addresses.list(@target_id_meta)[0]['id']
        tx_sent = SHELLEY.transactions.create(@wid,
                                              PASS,
                                              [{ address => amt }],
                                              nil,
                                              metadata
                                             )

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "Funds are on target wallet: #{@target_id_meta}" do
          available = SHELLEY.wallets.get(@target_id_meta)['balance']['available']['quantity']
          total = SHELLEY.wallets.get(@target_id_meta)['balance']['total']['quantity']
          (available == amt) && (total == amt)
        end

        eventually "Metadata is present on sent tx: #{tx_sent['id']}" do
          meta_src = SHELLEY.transactions.get(@wid, tx_sent['id'])['metadata']
          meta_dst = SHELLEY.transactions.get(@target_id_meta, tx_sent['id'])['metadata']
          (meta_src == metadata) && (meta_dst == metadata)
        end
      end

      it "I can estimate fee" do
        metadata = METADATA

        address = SHELLEY.addresses.list(@target_id)[0]['id']
        amt = [{ address => 1000000 }]

        txs = SHELLEY.transactions
        fees = txs.payment_fees(@wid, amt)
        expect(fees).to be_correct_and_respond 202

        fees = txs.payment_fees(@wid, amt, 'self')
        expect(fees).to be_correct_and_respond 202

        fees = txs.payment_fees(@wid, amt, 'self', metadata)
        expect(fees).to be_correct_and_respond 202
      end
    end

    describe "Stake Pools" do

      it "I could join Stake Pool - if I knew it's id" do
        pools = SHELLEY.stake_pools

        join = pools.join(SPID, @wid, PASS)
        expect(join).to be_correct_and_respond 404
        expect(join.to_s).to include "no_such_pool"
      end

      it "I could check delegation fees - if I could cover fee" do
        id = create_shelley_wallet

        pools = SHELLEY.stake_pools
        fees = pools.delegation_fees(id)
        expect(fees).to be_correct_and_respond 403
        expect(fees.to_s).to include "not_enough_money"
      end

      it "I could join Stake Pool - if I had enough to cover fee" do
        id = create_shelley_wallet
        pools = SHELLEY.stake_pools
        pool_id = pools.list({ stake: 1000 })[0]['id']

        join = pools.join(pool_id, id, PASS)
        expect(join).to be_correct_and_respond 403
        expect(join.to_s).to include "not_enough_money"
      end

      it "Can list stake pools only when stake is provided" do
        pools = SHELLEY.stake_pools
        l = pools.list({ stake: 1000 })
        l_bad = pools.list
        expect(l).to be_correct_and_respond 200

        expect(l_bad).to be_correct_and_respond 400
        expect(l_bad.to_s).to include "query_param_missing"
      end

      it "Can join and quit Stake Pool" do

        # Get funds on the wallet
        address = SHELLEY.addresses.list(@target_id_pools)[0]['id']
        amt = 10000000
        tx_sent = SHELLEY.transactions.create(@wid,
                                              PASS,
                                              [{ address => amt }])

        expect(tx_sent).to be_correct_and_respond 202
        expect(tx_sent.to_s).to include "pending"

        eventually "Funds are on target wallet: #{@target_id_pools}" do
          available = SHELLEY.wallets.get(@target_id_pools)['balance']['available']['quantity']
          total = SHELLEY.wallets.get(@target_id_pools)['balance']['total']['quantity']
          (available == amt) && (total == amt)
        end

        # Check wallet stake keys before joing stake pool
        stake_keys = SHELLEY.stake_pools.list_stake_keys(@target_id_pools)
        expect(stake_keys).to be_correct_and_respond 200
        expect(stake_keys['foreign'].size).to eq 0
        expect(stake_keys['ours'].size).to eq 1
        expect(stake_keys['ours'].first['stake']['quantity']).to eq amt
        expect(stake_keys['none']['stake']['quantity']).to eq 0
        expect(stake_keys['ours'].first['delegation']['active']['status']).to eq "not_delegating"
        expect(stake_keys['ours'].first['delegation']['next']).to eq []

        # Pick up pool id to join
        pools = SHELLEY.stake_pools
        pool_id = pools.list({ stake: 1000 }).sample['id']

        # Join pool
        puts "Joining pool: #{pool_id}"
        join = pools.join(pool_id, @target_id_pools, PASS)

        expect(join).to be_correct_and_respond 202
        expect(join.to_s).to include "status"

        join_tx_id = join['id']
        eventually "Checking if join tx id (#{join_tx_id}) is in_ledger" do
          tx = SHELLEY.transactions.get(@target_id_pools, join_tx_id)
          tx['status'] == "in_ledger"
        end

        # Check wallet stake keys after joing stake pool
        stake_keys = SHELLEY.stake_pools.list_stake_keys(@target_id_pools)
        expect(stake_keys).to be_correct_and_respond 200
        expect(stake_keys['foreign'].size).to eq 0
        expect(stake_keys['ours'].size).to eq 1
        expect(stake_keys['ours'].first['stake']['quantity']).to be > 0
        expect(stake_keys['none']['stake']['quantity']).to eq 0
        expect(stake_keys['ours'].first['delegation']['active']['status']).to eq "not_delegating"
        expect(stake_keys['ours'].first['delegation']['next'].first['status']).to eq "delegating"

        # Quit pool
        puts "Quitting pool: #{pool_id}"
        quit = pools.quit(@target_id_pools, PASS)

        expect(quit).to be_correct_and_respond 202
        expect(quit.to_s).to include "status"

        quit_tx_id = quit['id']
        eventually "Checking if quit tx id (#{quit_tx_id}) is in_ledger" do
          tx = SHELLEY.transactions.get(@target_id_pools, quit_tx_id)
          tx['status'] == "in_ledger"
        end

        # Check wallet stake keys after quitting stake pool
        stake_keys = SHELLEY.stake_pools.list_stake_keys(@target_id_pools)
        expect(stake_keys).to be_correct_and_respond 200
        expect(stake_keys['foreign'].size).to eq 0
        expect(stake_keys['ours'].size).to eq 1
        expect(stake_keys['ours'].first['stake']['quantity']).to be > 0
        expect(stake_keys['none']['stake']['quantity']).to eq 0
        expect(stake_keys['ours'].first['delegation']['active']['status']).to eq "not_delegating"
        expect(stake_keys['ours'].first['delegation']['next'].first['status']).to eq "not_delegating"
      end
    end

    describe "Coin Selection" do

      it "I can trigger random coin selection" do
        wid = create_shelley_wallet
        addresses = SHELLEY.addresses.list(wid)
        payload = [{ "address" => addresses[0]['id'],
                    "amount" => { "quantity" => 2000000, "unit" => "lovelace" },
                    "assets" => [ { "policy_id" => ASSETS[0]["policy_id"],
                                    "asset_name" => ASSETS[0]["asset_name"],
                                    "quantity" => 1
                                  },
                                  { "policy_id" => ASSETS[1]["policy_id"],
                                    "asset_name" => ASSETS[1]["asset_name"],
                                    "quantity" => 1
                                  }
                                ]
                    }
                   ]

        rnd = SHELLEY.coin_selections.random(@wid, payload, withdrawal = "self", m = METADATA)

        expect(rnd).to be_correct_and_respond 200
        expect(rnd.to_s).to include "outputs"
        expect(rnd.to_s).to include "change"
        expect(rnd.to_s).to include "metadata"
        expect(rnd['inputs']).not_to be_empty
        expect(rnd['outputs']).not_to be_empty
      end

      it "I can trigger random coin selection delegation action" do
        pid = SHELLEY.stake_pools.list({ stake: 1000000 }).sample['id']
        action_join = { action: "join", pool: pid }

        rnd = SHELLEY.coin_selections.random_deleg @wid, action_join

        expect(rnd).to be_correct_and_respond 200
        expect(rnd.to_s).to include "outputs"
        expect(rnd.to_s).to include "change"
        expect(rnd['inputs']).not_to be_empty
        expect(rnd['change']).not_to be_empty
        expect(rnd['outputs']).to be_empty
        expect(rnd['certificates']).not_to be_empty
        # expect(rnd['certificates'].to_s).to include "register_reward_account"
        expect(rnd['certificates'].to_s).to include "join_pool"
      end

      it "I could trigger random coin selection delegation action - if I had money" do
        wid = create_shelley_wallet
        pid = SHELLEY.stake_pools.list({ stake: 1000000 }).sample['id']
        action_join = { action: "join", pool: pid }

        rnd = SHELLEY.coin_selections.random_deleg wid, action_join
        expect(rnd).to be_correct_and_respond 403
        expect(rnd.to_s).to include "not_enough_money"
      end

      it "I could trigger random coin selection delegation action - if I known pool id" do
        wid = create_shelley_wallet
        addresses = SHELLEY.addresses.list(wid)
        action_join = { action: "join", pool: SPID_BECH32 }
        action_quit = { action: "quit" }

        rnd = SHELLEY.coin_selections.random_deleg wid, action_join
        expect(rnd).to be_correct_and_respond 404
        expect(rnd.to_s).to include "no_such_pool"

        rnd = SHELLEY.coin_selections.random_deleg wid, action_quit
        expect(rnd).to be_correct_and_respond 403
        expect(rnd.to_s).to include "not_delegating_to"
      end

    end
  end

  describe "E2E Byron" do

    def test_byron_tx(source_wid, target_wid)
      amt = 1000000
      address = SHELLEY.addresses.list(target_wid)[0]['id']

      tx_sent = BYRON.transactions.create(source_wid, PASS, [{ address => amt }])

      expect(tx_sent).to be_correct_and_respond 202
      expect(tx_sent.to_s).to include "pending"

      eventually "Funds are on target wallet: #{target_wid}" do
        available = SHELLEY.wallets.get(target_wid)['balance']['available']['quantity']
        total = SHELLEY.wallets.get(target_wid)['balance']['total']['quantity']
        (available == amt) && (total == amt)
      end
    end

    def test_byron_assets_tx(source_id, target_id)
      asset_quantity = 1
      address = SHELLEY.addresses.list(target_id)[1]['id']
      payload = [{ "address" => address,
                  "amount" => { "quantity" => 0, "unit" => "lovelace" },
                  "assets" => [ { "policy_id" => ASSETS[0]["policy_id"],
                                  "asset_name" => ASSETS[0]["asset_name"],
                                  "quantity" => asset_quantity
                                },
                                { "policy_id" => ASSETS[1]["policy_id"],
                                  "asset_name" => ASSETS[1]["asset_name"],
                                  "quantity" => asset_quantity
                                }
                              ]
                  }
                 ]

      tx_sent = BYRON.transactions.create(source_id, PASS, payload)

      expect(tx_sent).to be_correct_and_respond 202
      expect(tx_sent.to_s).to include "pending"

      eventually "Assets are on target wallet: #{target_id}" do
        first = ASSETS[0]["policy_id"] + ASSETS[0]["asset_name"]
        second = ASSETS[1]["policy_id"] + ASSETS[1]["asset_name"]
        total_assets = SHELLEY.wallets.get(target_id)['assets']['total']
        available_assets = SHELLEY.wallets.get(target_id)['assets']['available']
        total = Hash.new
        available = Hash.new

        unless total_assets.empty?
          total[first] = total_assets.select { |a| a['policy_id'] == ASSETS[0]["policy_id"] && a['asset_name'] == ASSETS[0]["asset_name"] }.first["quantity"]
          total[second] = total_assets.select { |a| a['policy_id'] == ASSETS[1]["policy_id"] && a['asset_name'] == ASSETS[1]["asset_name"] }.first["quantity"]
        end

        unless available_assets.empty?
          available[first] = available_assets.select { |a| a['policy_id'] == ASSETS[0]["policy_id"] && a['asset_name'] == ASSETS[0]["asset_name"] }.first["quantity"]
          available[second] = available_assets.select { |a| a['policy_id'] == ASSETS[1]["policy_id"] && a['asset_name'] == ASSETS[1]["asset_name"] }.first["quantity"]
        end

        (total[first] == asset_quantity) && (total[second] == asset_quantity) &&
        (available[first] == asset_quantity) && (available[second] == asset_quantity)
      end
    end

    describe "Byron Transactions" do

      it "I can send transaction and funds are received, random -> shelley" do
        test_byron_tx(@wid_rnd, @target_id_rnd_assets)
      end

      it "I can send transaction and funds are received, icarus -> shelley" do
        test_byron_tx(@wid_ic, @target_id_ic_assets)
      end
    end

    describe "Byron Migrations" do
      it "I can create migration plan byron -> shelley" do
        target_id = create_shelley_wallet
        addrs = SHELLEY.addresses.list(target_id).map { |a| a['id'] }

        plan = BYRON.migrations.plan(@wid_rnd, addrs)
        expect(plan).to be_correct_and_respond 202
        expect(plan['balance_selected']['assets']).not_to be []
        expect(plan['balance_leftover']).to eq ({ "ada" => { "quantity" => 0,
                                                         "unit" => "lovelace" },
                                                 "assets" => [] })
      end

      it "I can create migration plan icarus -> shelley" do
        target_id = create_shelley_wallet
        addrs = SHELLEY.addresses.list(target_id).map { |a| a['id'] }

        plan = BYRON.migrations.plan(@wid_ic, addrs)
        expect(plan).to be_correct_and_respond 202
        expect(plan['balance_selected']['assets']).not_to be []
        expect(plan['balance_leftover']).to eq ({ "ada" => { "quantity" => 0,
                                                         "unit" => "lovelace" },
                                                 "assets" => [] })
      end
    end

    describe "Native Assets" do

      it "I can list assets -> random" do
        assets = BYRON.assets.get @wid_rnd
        expect(assets).to be_correct_and_respond 200
        expect(assets.to_s).to include ASSETS[0]["policy_id"]
        expect(assets.to_s).to include ASSETS[0]["asset_name"]
        expect(assets.to_s).to include ASSETS[0]["metadata"]["name"]
        expect(assets.to_s).to include ASSETS[1]["policy_id"]
        expect(assets.to_s).to include ASSETS[1]["asset_name"]
        expect(assets.to_s).to include ASSETS[1]["metadata"]["name"]
      end

      it "I can list assets -> icarus" do
        assets = BYRON.assets.get @wid_ic
        expect(assets).to be_correct_and_respond 200
        expect(assets.to_s).to include ASSETS[0]["policy_id"]
        expect(assets.to_s).to include ASSETS[0]["asset_name"]
        expect(assets.to_s).to include ASSETS[0]["metadata"]["name"]
        expect(assets.to_s).to include ASSETS[1]["policy_id"]
        expect(assets.to_s).to include ASSETS[1]["asset_name"]
        expect(assets.to_s).to include ASSETS[1]["metadata"]["name"]
      end

      it "I can get native assets by policy_id -> random" do
        assets = BYRON.assets.get(@wid_rnd, policy_id = ASSETS[0]["policy_id"])
        expect(assets).to be_correct_and_respond 200
        expect(assets["policy_id"]).to eq ASSETS[0]["policy_id"]
        expect(assets["asset_name"]).to eq ASSETS[0]["asset_name"]
        expect(assets["metadata"]).to eq ASSETS[0]["metadata"]
        expect(assets["asset_name"]).not_to eq ASSETS[1]["asset_name"]
        expect(assets["metadata"]).not_to eq ASSETS[1]["metadata"]
      end

      it "I can get native assets by policy_id and asset_name -> random" do
        assets = BYRON.assets.get(@wid_rnd, policy_id = ASSETS[1]["policy_id"], asset_name = ASSETS[1]["asset_name"])
        expect(assets).to be_correct_and_respond 200
        expect(assets["policy_id"]).to eq ASSETS[1]["policy_id"]
        expect(assets["asset_name"]).to eq ASSETS[1]["asset_name"]
        expect(assets["metadata"]).to eq ASSETS[1]["metadata"]
        expect(assets["asset_name"]).not_to eq ASSETS[0]["asset_name"]
        expect(assets["metadata"]).not_to eq ASSETS[0]["metadata"]["name"]
      end

      it "I can send native assets tx and they are received (random -> shelley)" do
        test_byron_assets_tx(@wid_rnd, @target_id_rnd_assets)
      end

      it "I can send native assets tx and they are received (icarus -> shelley)" do
        test_byron_assets_tx(@wid_ic, @target_id_ic_assets)
      end

    end
  end


end
