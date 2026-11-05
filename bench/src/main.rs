use std::hint::black_box;
use std::time::{Duration, Instant};

const SIZES: [usize; 4] = [16, 1024, 128 * 1024, 512 * 1024];
const KEY: [u8; 32] = [7; 32];
const IV32: [u8; 32] = [9; 32];

/// MB/s of `f`, which processes `bytes` per call, over at least 400 ms.
fn rate(bytes: usize, mut f: impl FnMut()) -> f64 {
    for _ in 0..3 {
        f();
    }
    let batch = ((1usize << 20) / bytes).max(1);
    let start = Instant::now();
    let mut done = 0u64;
    while start.elapsed() < Duration::from_millis(400) {
        for _ in 0..batch {
            f();
        }
        done += (batch * bytes) as u64;
    }
    done as f64 / start.elapsed().as_secs_f64() / 1e6
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (arch, variant, pass) = (&args[1], &args[2], &args[3]);
    let report = |op: &str, size: usize, mbps: f64| println!("RESULT {arch} {variant} {op} {size} {pass} {mbps:.1}");

    #[cfg(feature = "new")]
    if pass == "1" {
        println!("INFO {arch} aes::hardware_accelerated() = {}", aes::hardware_accelerated());
    }

    for size in SIZES {
        let mut buf = vec![0u8; size];
        report("ige_encrypt", size, rate(size, || warpcrypto::ige256_encrypt(black_box(&mut buf), &KEY, &IV32).unwrap()));
        report("ige_decrypt", size, rate(size, || warpcrypto::ige256_decrypt(black_box(&mut buf), &KEY, &IV32).unwrap()));
        let (mut iv, mut state) = ([3u8; 16], 0u8);
        report("ctr256", size, rate(size, || warpcrypto::ctr256(black_box(&mut buf), &KEY, &mut iv, &mut state)));
    }

    // a long stream fed in small chunks: ctr256 per chunk vs one Ctr256
    #[cfg(feature = "new")]
    for size in [64usize, 256, 1024] {
        let mut buf = vec![0u8; size];
        let (mut iv, mut state) = ([3u8; 16], 0u8);
        report("chunks_ctr256", size, rate(size, || warpcrypto::ctr256(black_box(&mut buf), &KEY, &mut iv, &mut state)));
        let mut ctr = warpcrypto::Ctr256::new(&KEY, &[3; 16]);
        report("chunks_Ctr256", size, rate(size, || ctr.apply_keystream(black_box(&mut buf))));
    }
}
