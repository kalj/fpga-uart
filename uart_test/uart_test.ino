/* #define ARDUINO_BASIC_VERSION */
#define ARDUINO_PORT_VERSION
/* #define TEENSY_VERSION */

#if defined(ARDUINO_BASIC_VERSION)
#define NRST_PIN  A4
#define NCS_PIN   A3
#define RW_PIN    A2

uint8_t data_pins[] = {2, 3, 4, 5, 6, 7, 8, 9};
uint8_t addr_pins[] = {A0, A1};

static inline void set_rw(int lvl) {
    digitalWrite(RW_PIN, lvl);
}

static inline void set_ncs(int lvl) {
    digitalWrite(NCS_PIN, lvl);
}

static inline void set_nrst(int lvl) {
    digitalWrite(NRST_PIN, lvl);
}

void set_address(uint8_t addr) {
    digitalWrite(addr_pins[0], addr&0x1);
    digitalWrite(addr_pins[1], (addr>>1)&0x1);
}

void set_data(uint8_t data) {
    for(int i=0; i<8; i++) {
        digitalWrite(data_pins[i], (data>>i)&0x1);
    }
}

uint8_t get_data() {
    uint8_t data = 0;
    for(int i=0; i<8; i++) {
        data |= digitalRead(data_pins[i])<<i;
    }
    return data;
}

void set_data_dir(int dir) {
    for(int i=0; i<8; i++) {
        pinMode(data_pins[i], dir);
    }
}
#endif

#if defined(ARDUINO_PORT_VERSION)

#define NRST_PIN  A4
#define NCS_PIN   A3
#define RW_PIN    A2
#define NRST_BIT  4
#define NCS_BIT   3
#define RW_BIT    2

static inline void set_rw(int lvl) {
    if(lvl==HIGH) {
        PORTC |= (1<<RW_BIT);
    } else {
        PORTC &= ~(1<<RW_BIT);
    }
}

static inline void set_ncs(int lvl) {
    if(lvl==HIGH) {
        PORTC |= (1<<NCS_BIT);
    } else {
        PORTC &= ~(1<<NCS_BIT);
    }
}

static inline void set_nrst(int lvl) {
    if(lvl==HIGH) {
        PORTC |= (1<<NRST_BIT);
    } else {
        PORTC &= ~(1<<NRST_BIT);
    }
}

void set_address(uint8_t addr) {
    PORTC = (PORTC&(~B00000011)) | (addr&0x11);
}

void set_data(uint8_t data) {
    PORTB = (PORTB & B11111100) | ((data>>6)&B00000011);
    PORTD = (PORTD & B00000011) | ((data<<2)&B11111100);
}

uint8_t get_data() {
    return ((PINB&0x3)<<6)|((PIND&0xfc) >> 2);
}

void set_data_dir(int dir) {
    if(dir==OUTPUT) {
        DDRB = DDRB | B00000011; // pins 8-9 as output
        DDRD = DDRD | B11111100; // pins 2-7 as output
    } else {
        DDRB = DDRB & B11111100; // pins 8-9 as input
        DDRD = DDRD & B00000011; // pins 2-7 as input
    }
}
#endif

#if defined(TEENSY_VERSION)
#define NRST_PIN  12
#define NCS_PIN   11
#define RW_PIN    10

uint8_t data_pins[] = {14, 15, 16, 17, 18, 19, 20, 21};
uint8_t addr_pins[] = {8, 9};

static inline void set_rw(int lvl) {
    digitalWrite(RW_PIN, lvl);
}

static inline void set_ncs(int lvl) {
    digitalWrite(NCS_PIN, lvl);
}

static inline void set_nrst(int lvl) {
    digitalWrite(NRST_PIN, lvl);
}

void set_address(uint8_t addr) {
    digitalWrite(addr_pins[0], addr&0x1);
    digitalWrite(addr_pins[1], (addr>>1)&0x1);
}

void set_data(uint8_t data) {
    for(int i=0; i<8; i++) {
        digitalWrite(data_pins[i], (data>>i)&0x1);
    }
}

uint8_t get_data() {
    uint8_t data = 0;
    for(int i=0; i<8; i++) {
        data |= digitalRead(data_pins[i])<<i;
    }
    return data;
}

void set_data_dir(int dir) {
    for(int i=0; i<8; i++) {
        pinMode(data_pins[i], dir);
    }
}
#endif

void write_reg(uint8_t addr, uint8_t data) {

    set_address(addr);

    set_rw(LOW);

    set_data_dir(OUTPUT);
    set_data(data);

    set_ncs(LOW);
    delayMicroseconds(1);
    set_ncs(HIGH);
    delayMicroseconds(1);

    set_data_dir(INPUT);
    set_rw(HIGH);

}

uint8_t read_reg(uint8_t addr) {
    set_address(addr);

    // HIGH is default
    /* set_rw(HIGH); */

    // bus is input by default
    //set_data_dir(INPUT);

    set_ncs(LOW);
    delayMicroseconds(1);

    uint8_t data = get_data();
    set_ncs(HIGH);

    return data;
}

void send_char(char ch) {
    while(read_reg(0) & 0x1);
    write_reg(0, ch);
}

bool data_available() {
    return (read_reg(0) & 0x2) == 0x2;
}

char recv_char_blocking() {
    while(!data_available());
    return read_reg(1);
}

char recv_char_unblocking() {
    return read_reg(1);
}

void setup() {
    set_data_dir(INPUT);

    pinMode(NRST_PIN, OUTPUT);
    set_nrst(HIGH);

    pinMode(NCS_PIN, OUTPUT);
    set_ncs(HIGH);

    pinMode(RW_PIN, OUTPUT);
    set_rw(HIGH);

    for(int i=0; i<2; i++) {
        pinMode(addr_pins[i], OUTPUT);
    }
    set_address(0);

    delay(100);
    Serial.begin(115200);

}

#define BUFSIZE 80
char buf[BUFSIZE];

void loop() {
    while(Serial.available() > 0) {
        char ch = Serial.read();
        send_char(ch);
    }

    while(data_available()) {
        int n = 0;
        while( data_available() && n<(BUFSIZE-1)) {
            char ch = recv_char_unblocking();
            buf[n] = ch;
            n++;
        }

        if(n > 0) {
            buf[n] = 0;
            Serial.print(buf);
        }
    }
}

/*
const char charr[] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
uint8_t ch = 'A';

void loop() {

    for(int i=0; i<(int)sizeof(charr); i++) {
        send_char(charr[i]);
    }
    send_char('\n');

    // char ch = recv_char_unblocking();
    // Serial.print("received:  ");
    // Serial.println(ch);
    delay(100);
}
*/
