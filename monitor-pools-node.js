// Monitor de Pools via Node.js
// Detecta automaticamente quando novas pools são criadas
// Execute: node monitor-pools-node.js

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// Carregar .env
require('dotenv').config();

// Configuração
const RPC_URL = process.env.SEPOLIA_RPC_URL || process.env.MAINNET_RPC_URL;
const POOL_MANAGER_ADDRESS = process.env.POOL_MANAGER;
const TARGET_HOOK_ADDRESS = process.env.HOOK_ADDRESS?.toLowerCase();
const POOLS_FILE = path.join(__dirname, 'pools-detectadas.json');

// ABI do evento Initialize
const INITIALIZE_ABI = [
    "event Initialize(bytes32 indexed id, Currency indexed currency0, Currency indexed currency1, uint24 fee, int24 tickSpacing, Hooks indexed hooks, uint160 sqrtPriceX96, int24 tick)"
];

// ABI simplificado para PoolManager
const POOL_MANAGER_ABI = [
    "event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address indexed hooks, uint160 sqrtPriceX96, int24 tick)"
];

let detectedPools = {};

// Carregar pools já detectadas
function loadDetectedPools() {
    if (fs.existsSync(POOLS_FILE)) {
        try {
            const data = fs.readFileSync(POOLS_FILE, 'utf8');
            detectedPools = JSON.parse(data);
            console.log(`✅ Carregadas ${Object.keys(detectedPools).length} pools detectadas`);
        } catch (error) {
            console.error('❌ Erro ao carregar pools:', error.message);
        }
    }
}

// Salvar pools detectadas
function saveDetectedPools() {
    try {
        fs.writeFileSync(POOLS_FILE, JSON.stringify(detectedPools, null, 2));
        console.log('💾 Pools salvas');
    } catch (error) {
        console.error('❌ Erro ao salvar pools:', error.message);
    }
}

// Verificar se pool usa o hook correto
function isTargetPool(hooksAddress) {
    if (!TARGET_HOOK_ADDRESS) return true; // Se não especificado, monitora todas
    return hooksAddress.toLowerCase() === TARGET_HOOK_ADDRESS;
}

// Processar evento Initialize
async function processInitializeEvent(event) {
    const poolId = event.args.id;
    const currency0 = event.args.currency0;
    const currency1 = event.args.currency1;
    const fee = event.args.fee;
    const tickSpacing = event.args.tickSpacing;
    const hooks = event.args.hooks;
    const sqrtPriceX96 = event.args.sqrtPriceX96;
    const tick = event.args.tick;
    
    // Verificar se usa o hook correto
    if (!isTargetPool(hooks)) {
        return;
    }
    
    const poolKey = poolId;
    
    // Verificar se já foi detectada
    if (detectedPools[poolKey]) {
        return;
    }
    
    // Nova pool detectada!
    console.log('\n🎉 NOVA POOL DETECTADA!');
    console.log('  Pool ID:', poolId);
    console.log('  Currency0:', currency0);
    console.log('  Currency1:', currency1);
    console.log('  Fee:', fee.toString());
    console.log('  Tick Spacing:', tickSpacing.toString());
    console.log('  Hooks:', hooks);
    console.log('  SqrtPriceX96:', sqrtPriceX96.toString());
    console.log('  Tick:', tick.toString());
    
    // Adicionar à lista
    detectedPools[poolKey] = {
        poolId: poolId,
        poolManager: POOL_MANAGER_ADDRESS,
        hookAddress: hooks,
        token0: currency0,
        token1: currency1,
        fee: fee.toString(),
        tickSpacing: tickSpacing.toString(),
        detectedAt: new Date().toISOString()
    };
    
    saveDetectedPools();
    
    // Notificar (pode executar keeper aqui)
    console.log('✅ Pool adicionada ao monitoramento!');
}

// Monitorar eventos
async function monitorPools() {
    if (!RPC_URL || !POOL_MANAGER_ADDRESS) {
        console.error('❌ Configure RPC_URL e POOL_MANAGER no .env');
        process.exit(1);
    }
    
    console.log('=== Monitor de Pools - AutoCompound Hook ===\n');
    console.log('Configuração:');
    console.log('  RPC:', RPC_URL.substring(0, 50) + '...');
    console.log('  PoolManager:', POOL_MANAGER_ADDRESS);
    console.log('  Hook Alvo:', TARGET_HOOK_ADDRESS || 'Todas');
    console.log('');
    
    loadDetectedPools();
    
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const poolManager = new ethers.Contract(POOL_MANAGER_ADDRESS, POOL_MANAGER_ABI, provider);
    
    console.log('🔍 Monitorando eventos Initialize...\n');
    
    // Obter bloco atual
    const currentBlock = await provider.getBlockNumber();
    const fromBlock = Math.max(0, currentBlock - 10000); // Últimos 10k blocos
    
    console.log(`📊 Verificando blocos ${fromBlock} a ${currentBlock}...`);
    
    // Buscar eventos históricos
    try {
        const filter = poolManager.filters.Initialize();
        const events = await poolManager.queryFilter(filter, fromBlock, currentBlock);
        
        console.log(`📋 Encontrados ${events.length} eventos Initialize`);
        
        for (const event of events) {
            await processInitializeEvent(event);
        }
    } catch (error) {
        console.error('❌ Erro ao buscar eventos:', error.message);
    }
    
    // Monitorar novos eventos em tempo real
    console.log('\n👂 Ouvindo novos eventos...\n');
    
    poolManager.on('Initialize', async (...args) => {
        const event = {
            args: {
                id: args[0],
                currency0: args[1],
                currency1: args[2],
                fee: args[3],
                tickSpacing: args[4],
                hooks: args[5],
                sqrtPriceX96: args[6],
                tick: args[7]
            }
        };
        
        await processInitializeEvent(event);
    });
    
    // Manter processo vivo
    process.on('SIGINT', () => {
        console.log('\n\n👋 Encerrando monitor...');
        saveDetectedPools();
        process.exit(0);
    });
}

// Executar
monitorPools().catch(console.error);

