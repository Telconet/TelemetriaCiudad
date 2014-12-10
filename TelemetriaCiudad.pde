/*  
 *  ------ Waspmote Pro Code Example -------- 
 *  
 *  Explanation: This is the basic Code for Waspmote Pro
 *  
 *  Copyright (C) 2013 Libelium Comunicaciones Distribuidas S.L. 
 *  http://www.libelium.com 
 *  
 *  This program is free software: you can redistribute it and/or modify  
 *  it under the terms of the GNU General Public License as published by  
 *  the Free Software Foundation, either version 3 of the License, or  
 *  (at your option) any later version.  
 *   
 *  This program is distributed in the hope that it will be useful,  
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of  
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
 *  GNU General Public License for more details.  
 *   
 *  You should have received a copy of the GNU General Public License  
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.  
 */
     
// Put your libraries here (#include ...)

#include <WaspSensorPrototyping_v20.h>
#include <WaspFrame.h>
#include <WaspFrameConstants.h>
#include <WaspSensorCities.h>
#include <WaspWIFI.h>
#include <stdint.h>
#include <string.h>


#define USAR_POST
//#define USAR_DHCP
//#define USING_PROTO
//#define INUNDACIONES
//#define TELEMETRIA_CIUDAD
//#define CAMARONERA

//Equipo
#ifndef USAR_DHCP
#define IP_EQUIPO "172.19.84.24"
#define GW_EQUIPO "172.19.84.1"
#define NETMASK   "255.255.255.0"
#define PUERTO_EQUIPO 5001
#endif

//Servidor
#define IP_SERVIDOR "172.19.85.90"
#define PUERTO_SERVIDOR 5000

//Wifi...
#define SSID_RED "MunicipioTelemetria"
#define LLAVE_SSID "m3@Te"
#define TIMEOUT_WIFI 60000  //1 minuto

#define MINUTOS_SLEEP 10

#define WM_ID_EEPROM_START_ADD 1041

//Datos requeridos
#define CHG_WMID     12          //Cambiar waspmote id
#define STATUS       13          //Cargar waspmote id
#define SYNC_TIEMPO  14        //Cambiar hora


//Variables globales de informacion
float polvo = 0.0f;
float luminosidad = 0.0f;
float ruido = 0.0f;
float temperatura = 0.0f;
float humedad = 0.0f;          //%HR

//ID del waspmote
char waspmote_id[17] = {0};



void setup() {
    // put your setup code here, to run once:
    int encontrado = 0;
    
    // Init USB port
    USB.ON();
    USB.println(F("DM_02 example"));
    
    //Wifi
    configuracionWiFi();

    //Obtener tiempo y ID??
    //Verificamos que tenemos ID
    int i = 0;
    uint8_t tmp = 0;
  
    for(i = 0; i < 18; i++){
      tmp = Utils.readEEPROM(WM_ID_EEPROM_START_ADD + i);
  
      //Si direccion es invalida, tenemos que obtenerla...
      if(i == 0 && tmp != 'O'){
        break;
      }
      else if(i == 1 && tmp != 'K'){
        break;
      }
      else if(i >= 2){
        waspmote_id[i - 2] = (char)tmp;
      }
    }
  
    //si no tenemos el id, esperamos por él
    if(i < 2){
      encontrado = 0;
      while(encontrado != CHG_WMID){
        encontrado = enviarRecibirDatosTCPWifi(false);      //Llamamos esta funcion hasta que obtengamos el WM ID
      }
    }
    
    //Establecer reloj
    encontrado = 0;
    while(encontrado != SYNC_TIEMPO){
      encontrado = enviarRecibirDatosTCPWifi(false);      //Llamamos esta funcion hasta que obtengamos el WM ID
    }
    
    //RTC
    RTC.ON();    

}


void loop() {
    
    //Reloj... (10 minutos)
    RTC.setAlarm1(0, 0, MINUTOS_SLEEP, 0, RTC_ABSOLUTE, RTC_ALM1_MODE4);
    Utils.setLED(LED1, LED_ON);
    
    //dormir...
    PWR.sleep(ALL_OFF);
    USB.ON();
    RTC.ON(); 
    
    Utils.setLED(LED1, LED_OFF);
    Utils.setLED(LED0, LED_ON);
   
    //RTC interrupt levantará el waspmote...
    if( intFlag & RTC_INT )
    {
      intFlag &= ~(RTC_INT); // Clear flag
      USB.println(F("-------------------------"));
      USB.println(F("RTC INT Captured"));
      USB.println(F("-------------------------"));
      Utils.blinkLEDs(1000); // Blinking LEDs
      Utils.blinkLEDs(1000); // Blinking LEDs
    }    
    
    
    //Leemos sensores...
    SensorCities.ON();
    delay(2000);
    
    //Ruido... (dB)
    SensorCities.setSensorMode(SENS_ON, SENS_CITIES_AUDIO);
    delay(2000);
    ruido = SensorCities.readValue(SENS_CITIES_AUDIO);
    SensorCities.setSensorMode(SENS_OFF, SENS_CITIES_AUDIO);
    
    //Temperatura (°C)
    humedad = SensorCities.readValue(SENS_CITIES_HUMIDITY);
    
    //humedad (%HR)
    temperatura = SensorCities.readValue(SENS_CITIES_TEMPERATURE);
    
    //Luminosidad (%)
    SensorCities.setSensorMode(SENS_ON, SENS_CITIES_LDR);
    delay(10);

    luminosidad = SensorCities.readValue(SENS_CITIES_LDR);
    
    //polvo (mg/m3)
    polvo = SensorCities.readValue(SENS_CITIES_DUST);
    SensorCities.setSensorMode(SENS_OFF, SENS_CITIES_DUST);
  
    //Crear frame...
    //Creamos el paquete con la información de los sensors...
    frame.createFrame(ASCII, waspmote_id);                           //CHECK LEAKS!!!!!!!
    
    
    //TODO verificar que estos es menods de 150!!
    frame.setID(waspmote_id);
    frame.addSensor(SENSOR_TIME, RTC.hour, RTC.minute, RTC.second ); 
    frame.addSensor(SENSOR_DATE, RTC.year, RTC.month, RTC.date);      
    frame.addSensor(SENSOR_MCP, (float) ruido);
    frame.addSensor(SENSOR_DUST, (float) polvo);
    frame.addSensor(SENSOR_HUMA, (float) humedad);
    frame.addSensor(SENSOR_LUM, (float) luminosidad);
    frame.addSensor(SENSOR_TCA, (float) temperatura);
    frame.addSensor(SENSOR_BAT, (uint8_t) PWR.getBatteryLevel());
    
    //PAquete TCP... o POST??
#ifdef USAR_POST
    int status = WIFI.sendHTTPframe(IP, IP_SERVIDOR, PUERTO_SERVIDOR, frame.buffer, frame.length);      //primer argumento indica si el segundo es una IP o una URL
    
    if(status == 1){
      USB.print(F("Respuesta: "));
      USB.println(WIFI.answer);  
    }
    else{
      USB.println(F("Fallo solicitud HTTP"));
    }
#else
    //TCP...
    enviarRecibirDatosTCPWifi();
    delay(3000);
#endif
    
    
    SensorCities.OFF();
}


//WIFI
void configuracionWiFi(){
  
    //Configurar WIFI
    if( WIFI.ON(SOCKET0) == 1 )
    {    
      USB.println(F("WiFi switched ON"));
    }
    else
    {
      USB.println(F("WiFi did not initialize correctly"));
    }
    
    
     WIFI.setConnectionOptions(CLIENT);   //Cliente TCP...
     WIFI.setJoinMode(MANUAL); 

#ifdef USAR_DHCP
    WIFI.setDHCPoptions(DHCP_ON);   //or ON?
#else
    WIFI.setDHCPoptions(DHCP_OFF); 
    WIFI.setGW(GW_EQUIPO); 
    WIFI.setNetmask(NETMASK); 
    WIFI.setLocalPort(PUERTO_EQUIPO); 
    WIFI.setIp(IP_EQUIPO);
#endif
    
    WIFI.setAuthKey(WPA1, LLAVE_SSID); 

    //Guardar  
    WIFI.storeData();
}

//Cliente TCP
int enviarRecibirDatosTCPWifi(bool responder){
  
  int encontrado = 0;
  
  WIFI.ON(SOCKET0);
    
  if(WIFI.join(SSID_RED)){
  
   if(responder){   
      //Si la conexion pudo ser abierta...
      if(WIFI.setTCPclient(IP_SERVIDOR, PUERTO_SERVIDOR, PUERTO_EQUIPO)){
          WIFI.send(frame.buffer,frame.length);
      } 
      
      USB.println(F("Close TCP socket"));
      WIFI.close(); 
   }
   else{
     //Caso contrario, vamos a recibir un paquete con información
     //Crear conexion
     if (WIFI.setTCPclient(IP_SERVIDOR, PUERTO_SERVIDOR, PUERTO_EQUIPO)){
       
       unsigned long previo = 0;
       
       previo = millis();        //Obtenemos millis de tiempo actual
       
       //Escuchamos durante un tiempo igual a TIMEOUT_WIFI (usualmente 60 min...
       while(millis() - previo < TIMEOUT_WIFI){
         
          WIFI.read(BLO);  //leemos sin bloquear
          
          if(WIFI.length > 0){    //tenemos informacion
            //TODO procesar informacion
            encontrado = 0;
            bool enviar = procesarInformacion(WIFI.answer, &encontrado);
            
            //Si al procesar informacion necesitamos enviar un frame, lo hacemos.
            if(responder){
              WIFI.send(frame.buffer,frame.length);
            }
          }
          
          //para evitar overflow del tiempo
          if (millis() < previo)
          {
            previo = millis();	
          }
       }
       //fin del while
     }
   }
  }
  
  WIFI.close();
  WIFI.OFF();
  
  return encontrado;
  
}

//Procesar comando.
//Comandos validos pueden ser
//CWMID<nombre>: cambiamos nombre del Waspmote.
//LWMDID: mandamos waspmote id
//CHORA: establecemos la hora del RTC
bool procesarInformacion(char *info, int *encontrado){
  //TODO
  
   char *indice = NULL;
   *encontrado = 0;                                //Si encontramos un comando distinto al requerido?
  
   if( (indice = strstr(info, "CHG_WMID")) != NULL){
     
     //Cambiar waspmote id
     *encontrado = CHG_WMID;
     
     int i = 0;
     indice += 5;    //Apuntamos a donde inicia el nuevo waspmote ID   -> CWMIDmiwaspmoteid4567\0, 
                     //Si es nombre corto (< 16 chars) -> CWMIDmiwaspmote\0\0\0\0\0   
                     //Si nombre es mas corto, llenamos con 0s
     
     Utils.writeEEPROM(WM_ID_EEPROM_START_ADD, 'O');
     Utils.writeEEPROM(WM_ID_EEPROM_START_ADD + 1, 'K');
     
     for(i = 2; i < 18; i++){
        Utils.writeEEPROM(WM_ID_EEPROM_START_ADD + i, info[i]);        //CHECK BOUNDS!!
        waspmote_id[i - 2] = info[i];                                  //cambiamos ID.
     }
     return false;
   }
   else if( (indice = strstr(info, "STATUS")) != NULL){
     
     //Leer waspmote id
     *encontrado = STATUS;
     frame.createFrame(ASCII, waspmote_id);                              //PROBAR LEAKS!!!
     frame.addSensor(SENSOR_BAT, (uint8_t) PWR.getBatteryLevel()); 
     frame.addSensor(SENSOR_STR, IP_EQUIPO);                             //IP     
     return true;
     
   }
   else if((indice = strstr(info, "SYNC_TIEMPO")) != NULL){
     
     //Cambiar hora del waspmote
     *encontrado = SYNC_TIEMPO;
     
     //SYNC_TIEMPO14:01:21:07:13:45:21\0
     indice += 11;
     
     //Tiempo en formato [yy:mm:dd:dow:hh:mm:ss]
     RTC.setTime(indice);        //mandamos hora
     
   } 
}



