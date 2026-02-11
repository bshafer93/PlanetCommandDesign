export interface Vehicle {
  id: string;
  name: string;
  lengthM: number; // real-world length in meters
  category: 'plane' | 'ship';
  file: string; // filename in third-party/planes/ or third-party/ships/
}

export const planes: Vehicle[] = [
  // Modern Jets
  { id: 'f16', name: 'F-16 Fighting Falcon', lengthM: 15.06, category: 'plane', file: 'f16.svg' },
  { id: 'f22', name: 'F-22 Raptor', lengthM: 18.92, category: 'plane', file: 'f22.svg' },
  { id: 'f15', name: 'F-15 Eagle', lengthM: 19.43, category: 'plane', file: 'f15.svg' },
  { id: 'fa18', name: 'F/A-18 Super Hornet', lengthM: 18.31, category: 'plane', file: 'fa18.svg' },
  { id: 'f8', name: 'F-8 Crusader', lengthM: 16.61, category: 'plane', file: 'f8-crusader.svg' },
  { id: 'su27', name: 'Su-27 Flanker', lengthM: 21.94, category: 'plane', file: 'su27.svg' },
  { id: 'sukhoi', name: 'Sukhoi (generic)', lengthM: 21.0, category: 'plane', file: 'sukhoi.svg' },
  { id: 'sea-harrier', name: 'Sea Harrier', lengthM: 14.50, category: 'plane', file: 'sea-harrier.svg' },
  { id: 'me262', name: 'Me 262 Schwalbe', lengthM: 10.60, category: 'plane', file: 'me262.svg' },
  { id: 'fighter-generic', name: 'Fighter Jet (generic)', lengthM: 15.0, category: 'plane', file: 'fighter-generic.svg' },
  { id: 'fighter-detailed', name: 'Fighter Jet (detailed)', lengthM: 15.0, category: 'plane', file: 'fighter-detailed.svg' },

  // WW2 Fighters
  { id: 'p51', name: 'P-51B Mustang', lengthM: 9.83, category: 'plane', file: 'p51.svg' },
  { id: 'p38', name: 'P-38 Lightning', lengthM: 11.53, category: 'plane', file: 'p38.svg' },
  { id: 'fw190', name: 'Fw 190 A-8', lengthM: 8.84, category: 'plane', file: 'fw190.svg' },
  { id: 'ju87', name: 'Ju 87 Stuka', lengthM: 11.07, category: 'plane', file: 'ju87.svg' },
  { id: 'typhoon', name: 'Hawker Typhoon', lengthM: 9.73, category: 'plane', file: 'hawker-typhoon.svg' },
  { id: 'mosquito', name: 'De Havilland Mosquito', lengthM: 12.43, category: 'plane', file: 'mosquito.svg' },
  { id: 'swordfish', name: 'Fairey Swordfish', lengthM: 10.87, category: 'plane', file: 'swordfish.svg' },

  // Bombers & Transports
  { id: 'b29', name: 'B-29 Superfortress', lengthM: 30.18, category: 'plane', file: 'b29.svg' },
  { id: 'b25', name: 'B-25 Mitchell', lengthM: 16.13, category: 'plane', file: 'b25.svg' },
  { id: 'b24', name: 'B-24 Liberator', lengthM: 20.47, category: 'plane', file: 'b24.svg' },
  { id: 'lancaster', name: 'Avro Lancaster', lengthM: 21.18, category: 'plane', file: 'lancaster.svg' },
  { id: 'tu95', name: 'Tu-95 Bear', lengthM: 49.13, category: 'plane', file: 'tu95.svg' },
  { id: 'b58', name: 'B-58 Hustler', lengthM: 29.49, category: 'plane', file: 'b58.svg' },
  { id: 'ju52', name: 'Junkers Ju 52', lengthM: 18.90, category: 'plane', file: 'junkers52.svg' },
  { id: 'avenger', name: 'TBF Avenger', lengthM: 12.48, category: 'plane', file: 'avenger.svg' },
];

export const ships: Vehicle[] = [
  // Aircraft Carriers
  { id: 'nimitz', name: 'USS Nimitz (CVN-68)', lengthM: 332.8, category: 'ship', file: 'carrier-nimitz.svg' },

  // Battleships & Cruisers
  { id: 'battleship', name: 'Battleship (generic)', lengthM: 200, category: 'ship', file: 'battleship.svg' },
  { id: 'belfast', name: 'HMS Belfast', lengthM: 187, category: 'ship', file: 'belfast.svg' },
  { id: 'sheffield', name: 'HMS Sheffield', lengthM: 125, category: 'ship', file: 'sheffield.svg' },
  { id: 'arethusa', name: 'HMS Arethusa', lengthM: 154, category: 'ship', file: 'arethusa.svg' },
  { id: 'london', name: 'HMS London', lengthM: 192, category: 'ship', file: 'london.svg' },
  { id: 'atago', name: 'IJN Atago', lengthM: 203.76, category: 'ship', file: 'atago.svg' },
  { id: 'tone', name: 'IJN Tone', lengthM: 201.6, category: 'ship', file: 'tone.svg' },
  { id: 'nachi', name: 'IJN Nachi', lengthM: 203.76, category: 'ship', file: 'nachi.svg' },
  { id: 'adelaide', name: 'HMAS Adelaide', lengthM: 138.1, category: 'ship', file: 'adelaide.svg' },

  // Frigates & Destroyers
  { id: 'german-frigate', name: 'German Frigate', lengthM: 143, category: 'ship', file: 'german-frigate.svg' },
  { id: 'spanish-f100', name: 'Spanish F100 Frigate', lengthM: 146.7, category: 'ship', file: 'spanish-f100.svg' },
  { id: 'uss-mertz', name: 'USS Mertz (DD-691)', lengthM: 114.76, category: 'ship', file: 'uss-mertz.svg' },
  { id: 'warship-silhouette', name: 'Warship (silhouette)', lengthM: 150, category: 'ship', file: 'warship-silhouette.svg' },
  { id: 'military-boat', name: 'Military Boat', lengthM: 100, category: 'ship', file: 'military-boat.svg' },

  // Submarines
  { id: 'soviet-sub', name: 'Soviet Sub S-56', lengthM: 97.65, category: 'ship', file: 'soviet-sub-s56.svg' },
  { id: 'akula-sub', name: 'Akula-class Sub', lengthM: 110, category: 'ship', file: 'akula-sub.svg' },
  { id: 'german-sub', name: 'German Submarine', lengthM: 67.1, category: 'ship', file: 'german-sub.svg' },
  { id: 'u155', name: 'U-155 Submarine', lengthM: 65, category: 'ship', file: 'u155-sub.svg' },
  { id: 'vintage-uboat', name: 'Vintage U-Boat', lengthM: 60, category: 'ship', file: 'vintage-uboat.svg' },
];

export const allVehicles: Vehicle[] = [...planes, ...ships];
