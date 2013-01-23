#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw(sum);
use Device::USB::PCSensor::HidTEMPer;
use Data::Dumper;

#** @var $fh default fileHandler
my $fh;

#** @var $temperature stores multible temperatures
my $temperature;
#** @var $hydro stores multible hydro values 
my $hydro;

#** @var @temp multi purporage XXX storage
my @temp;
#** @var $debug debug flag, 3 print return values, 4 print temperatures, 5 print function references
my $debug=1;
#** @var $temper stores HidTEMPer object
my $temper;
#** @var @curTemp stores current temperature
my @curTemp;
#** @var $curHum stores current humidity
my $curHum;

my $call;

#** @function public  getDHT11($gpio)
# @brief get DHT11 temperature and humidity
# @param requiered $gpio gpio where sensor is connected
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getDHT11{
        if($debug >= 3){
                print "\tgetDHT11\n";
        }

        if( !(-r '/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT') ){
                return -1;
        }

        @temp = `/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT 11 $_[0]`;
	
	if( !(defined $temp[2]) ){
		return -1;
	}

        if( !($temp[2] =~ m/^Temp\ =\ (.*)\*C/) ){
                return -1;
        }
        else{  
                $curTemp[0] = $1;
        }

	if( !($temp[2] =~ m/Hum\ =\ (.*)\ \%/) ){
                return -1;
        }
        else{
                $curTemp[1] = $1;
        }
	system("echo `date +%Y-%m-%d_%H:%M:%S` @curTemp >> /tmp/dht11_$_[0]"); 
	return @curTemp;
}


#** @function public  getHidTEMPer()
# @brief get HidTEMPer temperature 
# @todo add UniqID if possible need another sensor!
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getHidTEMPer{
        if($debug >= 3){
                print "\tgetHidTEMPer\n";
        }

	my $temper = Device::USB::PCSensor::HidTEMPer->new();
	#** @var $sensorID XXX
	my $sensorID = $temper->device();

	if(defined $sensorID->internal() ){
		$curTemp[0] = $sensorID->internal()->celsius();
	}
	else{
		return -1;
	}

	if($curTemp[0] < -40 || $curTemp[0] > 120){	# || $curTemp[0] == 53.171875){
                return -1;
        }

	system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp[0] >> /tmp/hidtemper");
	return $curTemp[0];
}

#** @function public bcm2708Temp ()
# @brief get bcm2708 temperature 
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getBCM2708{
        if($debug >= 3){
                print "\tgetBCM2708\n";
        }

        if( !(-r '/opt/vc/bin/vcgencmd') ){
                return -1;
        }

        @temp = `/opt/vc/bin/vcgencmd measure_temp`;
        if( !($temp[0] =~ m/^temp=(.*)'C$/) ){
                return -1;
        }
        else{
                $curTemp[0] = $1;
        }
	system("echo `date +%Y-%m-%d_%H:%M:%S` @curTemp >> /tmp/bcm2708");
        return $curTemp[0];
}


#** @function public getTempDS1820 ($ID)
# @brief get DS1820 temperature 
# @param requiered $ID ID of Sensor
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub getTempDS1820{
	if($debug >= 3){
		print "\tgetTempDS1820\n";
	}

	open($fh, "<", "/sys/bus/w1/devices/$_[0]/w1_slave") or return "-1";
	#** @var @temp stores recived string
	@temp = <$fh>;
	close($fh);

        if(  !($temp[0]=~ m\YES\) ){
                return -1;
        }
	elsif( !($temp[1]=~ m\t=(.*)\) ){
		return -1;
	}
	elsif($1 < -55000 || $1 > 125000){
		return -1;
	}
	else{
		$curTemp[0] = $1/1000;
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp[0] >> /tmp/ds1820_$_[0]");
#		system("echo `date +%Y-%m-%d_%H:%M:%S` $temp[0] $temp[1] $temp[2] >> /tmp/ds1820_debug_$_[0]");

        	open ($fh, "+>>/tmp/ds1820_debug_$_[0]") || die "cant open file /tmp/ds1820_debug_$_[0]: $!\n";
	        print $fh @temp;
		close $fh;


		return $curTemp[0];
	}
}

#** @function public avgTemp ($func, $count, $tolerance, $sensorID])
# @brief get DS1820 temperature 
# @param required $func $_[0] XXX
# @param required $count $_[1] XXX
# @param required $tolerance $_[2] XXX
# @param required $sleep $_[3]
# @param optional $sensorID $_[4] XXX
# @todo if array value 'U' delete item
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 

#sub fillArray{
sub avgTemp{
	my $i;
#	$call = ( caller(0) )[1];
#	if($debug >=3){
#		print "caller: $call\n";
#	}

	undef $temperature;
	undef $hydro;

	for($i=0, $i<$_[1], $i++){
		# if Temperature+Hydro
		if( ($_[0]) eq (\&getDHT11) ){
			if($_[0]($_[4]) != -1){
				if( !(defined $temperature) or !(defined $hydro) ){
					$temperature = $curTemp[0];
					$hydro = $curTemp[1];
				}
				else{  
					$temperature = ($curTemp[0]+$temperature)/2;
					$hydro = ($curTemp[1]+$hydro)/2;
				}
			}
		}
		# if Temperature
		else{
			if($_[0]($_[4]) != -1){
				if( !(defined $temperature) or !(defined $hydro) ){
					$temperature = $curTemp[0];
				}
				else{   
					$temperature = ($curTemp[0]+$temperature)/2;
				}
			}
		}
	sleep($_[3]);
	}

	if( ($_[0]) eq (\&getDHT11) ){	
		if($debug >= 3){
			print "fillArray -> temperature:$temperature hydro:$hydro\n";
		}
		 return ( $temperature, $hydro );
	}
	else{
		if($debug >= 3){
			print "fillArray -> temperature:$temperature\n";
		}
		return $temperature;
	}
}


=com

#** @function public avgTemp ($func, $count, $tolerance, $sensorID])
# @brief get DS1820 temperature 
# @param required $func XXX
# @param required $count XXX
# @param required $tolerance XXX
# @param optional $sensorID XXX
# @todo if array value 'U' delete item
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub avgTemp{

	$call = ( caller(0) )[1];

	fillArray($_[0], $_[1], $_[3]);
#	print Dumper @temperature;
#	print Dumper @hydro;
#	print "sensors.pm\tavgTemp: ", (sum(@temperature)/@temperature);
#	print "\tavgHydro: ", (sum(@hydro)/@hydro);
	
	return ( $temperature, $hydro );
}
=cut

1;
