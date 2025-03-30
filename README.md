# MEV Taxes, testing in production

# *Swap fees porportional to priority fee*

Deployed on Unichain:

https://uniscan.xyz/address/0xb9a17e66db950e00822c2b833d6bb304c9b86080

Vanilla LP:

https://app.uniswap.org/positions/v4/unichain/30668

MEV-Tax LP:

https://app.uniswap.org/positions/v4/unichain/30667

---

[Override fees](https://docs.uniswap.org/contracts/v4/concepts/dynamic-fees) allow for per-transaction swap fees. The MEV-tax test-in-prod, will charge a maximum fee of 69 bips for the highest-priority-fee in a block. All other swaps pay a fee porportional the highest-priority-fee, with a minimum fee of 4.5 bips.

For example:

* Highest priority fee in a block: 1 gwei
    * swapper pays 69 bips

* A swap in the block pays a 0.25 gwei fee
    * swapper pays 17.25 bips (1/4th of 69 bips)

---

Test in prod, so I have admin permissions to set the default max fee and the default minimum fee 🤷
