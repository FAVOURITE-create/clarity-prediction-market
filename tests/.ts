import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test market creation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('prediction-market', 'create-market', [
                types.ascii("Will BTC reach 100k by 2024?"),
                types.uint(1735689600)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
    },
});

Clarinet.test({
    name: "Test buying shares",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('prediction-market', 'create-market', [
                types.ascii("Will ETH reach 10k by 2024?"),
                types.uint(1735689600)
            ], deployer.address),
            
            Tx.contractCall('prediction-market', 'buy-shares', [
                types.uint(1),
                types.bool(true),
                types.uint(100)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
    },
});
