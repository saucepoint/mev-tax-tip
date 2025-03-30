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

---

## Disclaimer

This Uniswap v4 Hook and Pool are provided herein is offered on an “as-is” basis and has not been audited for security, reliability, or compliance with any specific standards or regulations. It may contain bugs, errors, or vulnerabilities that could lead to unintended consequences.

By utilizing this Uniswap v4 Hook, you acknowledge and agree that:

- Assumption of Risk: You assume all responsibility and risks associated with its use.
- No Warranty: The authors and distributors of this code, namely, saucepoint, disclaim all warranties, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement.
- Limitation of Liability: In no event shall the authors or distributors be held liable for any damages or losses, including but not limited to direct, indirect, incidental, or consequential damages arising out of or in connection with the use or inability to use the code.
- Recommendation: Users are strongly encouraged to review, test, and, if necessary, audit the community router independently before deploying in any environment.

By proceeding to utilize this Uniswap v4 Hook, you indicate your understanding and acceptance of this disclaimer.
