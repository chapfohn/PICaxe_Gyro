SDA            PIN      0       ' SDA of gyro connected to P0
SCL            PIN      1       ' SCL of gyro connected to P1

WRITE_Data     CON      $D2     ' Request Write operation
READ_Data      CON      $D3     ' Request Read operation

' Control registers
CTRL_REG1      CON      $20
CTRL_REG2      CON      $21
CTRL_REG3      CON      $22
CTRL_REG4      CON      $23
STATUS_REG     CON      $27
OUT_X_INC      CON      $A8

X              VAR      Word   'roll
Y              VAR      Word   'pitch
Z              VAR      Word   'yaw
rawl           VAR      Word
rawh           VAR      Word

' Variables for I2C communications
I2C_DATA       VAR      Byte
I2C_LSB        VAR      Bit
I2C_REG        VAR      Byte
I2C_VAL        VAR      Byte

PAUSE 100                       ' Power up delay

' Set up data ready signal
I2C_REG = CTRL_REG3
I2C_VAL = $08
GOSUB I2C_Write_Reg

' Set up "block data update" mode
I2C_REG = CTRL_REG4
I2C_VAL = $80
GOSUB I2C_Write_Reg

' Send the get continuous output command
I2C_REG = CTRL_REG1
I2C_VAL = $1F
GOSUB I2C_Write_Reg

DO
  GOSUB Gyro_Get_Raw                       ' Get XYZ data

  ' Divide X Y Z, by 114 to reduce noise
  IF (X.BIT15) THEN
    X = (ABS X) / 114
    X = -X
  ELSE
    X = X / 114
  ENDIF
  IF (Y.BIT15) THEN
    Y = (ABS Y) / 114
    Y = -Y
  ELSE
    Y = Y / 114
  ENDIF
  IF (Z.BIT15) THEN
    Z = (ABS Z) / 114
    Z = -Z
  ELSE
    Z = Z / 114
  ENDIF

  DEBUG "RAW X = ",11, SDEC X, TAB, "RAW Y = ",11, SDEC Y, TAB, "RAW Z = ",11, SDEC Z, CR
  PAUSE 250

LOOP

Gyro_Get_Raw:
  GOSUB Wait_For_Data_Ready

  GOSUB I2C_Start

  I2C_DATA = WRITE_DATA
  GOSUB I2C_Write                         ' Read the data starting
  I2C_DATA = OUT_X_INC        '   at pointer register
  GOSUB I2C_Write

  GOSUB I2C_Stop

  GOSUB I2C_Start
  I2C_DATA = READ_DATA
  GOSUB I2C_Write

  GOSUB I2C_Read
  rawL = I2C_DATA                         ' Read high byte
  GOSUB I2C_ACK

  GOSUB I2C_Read
  rawH = I2C_DATA                         ' Read low byte
  GOSUB I2C_ACK
  X = (rawH <&lt 8) | rawL                  ' OR high and low into X

  ' Do the same for Y and Z:
  GOSUB I2C_Read
  rawL = I2C_DATA
  GOSUB I2C_ACK

  GOSUB I2C_Read
  rawH = I2C_DATA
  GOSUB I2C_ACK
  Y = (rawH <&lt 8) | rawL

  GOSUB I2C_Read
  rawL = I2C_DATA
  GOSUB I2C_ACK

  GOSUB I2C_Read
  rawH = I2C_DATA
  GOSUB I2C_NACK
  Z = (rawH << 8) | rawL

  GOSUB I2C_Stop

RETURN

'---------I2C functions------------
' Read the status register until the ZYXDA bit is high
Wait_For_Data_Ready:
DO
  I2C_REG = STATUS_REG
  GOSUB I2C_Read_Reg
LOOP UNTIL ((I2C_DATA & $08) <> 0)
RETURN

' Set I2C_REG & I2C_VAL before calling this
I2C_Write_Reg:
  GOSUB I2C_Start
  I2C_DATA = WRITE_DATA
  GOSUB I2C_Write
  I2C_DATA = I2C_REG
  GOSUB I2C_Write
  I2C_DATA = I2C_VAL
  GOSUB I2C_Write
  GOSUB I2C_Stop
RETURN

' Set I2C_REG before calling this, I2C_DATA will have result
I2C_Read_Reg:
  GOSUB I2C_Start
  I2C_DATA = WRITE_DATA
  GOSUB I2C_Write
  I2C_DATA = I2C_REG
  GOSUB I2C_Write
  GOSUB I2C_Stop
  GOSUB I2C_Start
  I2C_DATA = READ_DATA
  GOSUB I2C_Write
  GOSUB I2C_Read
  GOSUB I2C_NACK
  GOSUB I2C_Stop
RETURN

I2C_Start:
  LOW SDA
  LOW SCL
RETURN

I2C_Stop:
  LOW   SDA
  INPUT SCL
  INPUT SDA
RETURN

I2C_ACK:
  LOW   SDA
  INPUT SCL
  LOW   SCL
  INPUT SDA
RETURN

I2C_NACK:
  INPUT SDA
  INPUT SCL
  LOW   SCL
RETURN

I2C_Read:
  SHIFTIN SDA, SCL, MSBPRE, [I2C_DATA]
  RETURN

I2C_Write:
  I2C_LSB = I2C_DATA.BIT0
  I2C_DATA = I2C_DATA / 2
  SHIFTOUT SDA, SCL, MSBFIRST, [I2C_DATA\7]
  IF I2C_LSB THEN INPUT SDA ELSE LOW SDA
  INPUT SCL
  LOW SCL
  INPUT SDA
  INPUT SCL
  LOW SCL
RETURN