# 🚀 Projekt: SubscriptionPlatform

## 📂 Källkod

- **`SubscriptionPlatform.sol`** – smart kontrakt som hanterar prenumerationstjänster, inklusive:
  - 📝 Skapande av tjänster
  - 🔔 Prenumerationer
  - ⏸ Pausning
  - 💰 Prisändring
  - 💸 Uttag
  - 🎁 Gåvor av prenumerationer

- **`SubscriptionPlatform.ts`** – tester för kontraktet som verifierar:
  - ✅ Funktionalitet
  - 👑 Ägarskap
  - 📅 Prenumerationslogik
  - 🎁 Gåvor
  - 🔒 Säkerhetskontroller

---

## ⚡ Gasoptimeringar

### 💾 Lagring av endast nödvändiga värden

- Vi använder **`structs`** (`SubscriptionService` och `UserSubscription`) med endast de fält som behövs.  
- Undviker onödiga variabler och temporära arrays.

### 🗂 Mapping istället för arrays

- Användning av **`mapping(uint => SubscriptionService)`** och **`mapping(uint => mapping(address => UserSubscription))`** istället för arrays minskar gas vid läsning och skrivning.

### 🛠 Uppdatering av state sparsamt

- **`balance`** och **`expiry`** uppdateras endast när det behövs.  
- I **`subscribe`** lägger vi till period istället för att skriva om hela structen.

### ⏸ Pausning via boolean

- **`paused`** används istället för att ta bort tjänster. En boolean är billigare än att manipulera arrays.

---

## 🛡 Säkerhetsåtgärder

### 👑 Modifier `onlyOwner`

- Säkerställer att endast tjänstens ägare kan:
  - 💰 Ändra pris
  - ⏸ Pausa tjänsten
  - ▶️ Återuppta tjänsten
  - 💸 Ta ut Ether

### ⏱ Modifier `serviceActive`

- Förhindrar interaktion med tjänster som är pausade, vilket skyddar användare från oönskade transaktioner.

### 🎁 Kontroller vid gåvor

- **`giftSubscription`** kräver att avsändaren har aktiv prenumeration.  
- Mottagarens prenumeration förlängs korrekt.

### 💸 Säker Ether-överföring

```solidity
// Vid withdraw används call och balance sätts till 0 innan
(bool sent, ) = service.owner.call{value: amount}("");
require(sent, "Failed to send Ether");

Skyddar mot reentrancy-problem.

⚠️ Require-satser

Varje kritisk funktion har require-kontroller för att förhindra:

Otillåten åtkomst

Felaktiga betalningar

🧪 Testning

Testat med Hardhat 3 och TypeScript, inklusive edge-cases:

⏳ Förlängning av prenumerationer

🎁 Gåvor till användare med eller utan aktiv prenumeration

❌ Försök från icke-ägare att manipulera tjänster

💸 Uttag av Ether och korrekt uppdatering av balance
