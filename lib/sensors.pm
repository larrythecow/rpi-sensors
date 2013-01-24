#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw(sum);
use POSIX;
use Device::USB::PCSensor::HidTEMPer;
use Data::Dumper;

#** @var $fh default fileHandler
my $fh;
#** @var @temp multi purporage XXX storage
my @temp;
#** @var $debug debug flag, 3 print return values, 4 print temperatures, 5 print function references
my $debug=1;
my $LogPath="/tmp/sensor-debug";

my $call;

#** @function public  getDHT11($gpio)
# @brief get DHT11 temperature and humidity
# @param requiered $gpio gpio where sensor is connected
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getDHT11{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var $curHum stores current humidity
	my $curHum;

        if($debug >= 3){
                print "\tgetDHT11\n";
        }

        if( !(-r '/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT') ){
                return (-1, -1);
        }

        @temp = `/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT 11 $_[0]`;
	
	if( !(defined $temp[2]) ){
		return (-1, -1);
	}

        if( !($temp[2] =~ m/^Temp\ =\ (.*)\*C/) ){
                return (-1, -1);
        }
        else{  
                $curTemp = $1;
        }

	if( !($temp[2] =~ m/Hum\ =\ (.*)\ \%/) ){
                return (-1, -1);
        }
        else{
                $curHum = $1;
        }

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp $curHum >> $LogPath/dht11_$_[0]");
		if($debug >=2){
			print "\t\tgetDHT11 $curTemp $curHum\n";
		}
	}
	
	return ($curTemp, $curHum);
}


#** @function public  getHidTEMPer()
# @brief get HidTEMPer temperature 
# @todo add UniqID if possible need another sensor!
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getHidTEMPer{
	#** @var @curTemp stores current temperature
	my $curTemp;
	my $temper;
	my $sensor;

        if($debug >= 3){
                print "\tgetHidTEMPer\n";
        }

	$temper = Device::USB::PCSensor::HidTEMPer->new();
	#** @var $sensorID XXX
	$sensor = $temper->device();

	if(defined $sensor->internal() ){
		$curTemp = $sensor->internal()->celsius();
	}
	else{
		return -1;
	}

	if($curTemp < -40 || $curTemp > 120){	# || $curTemp[0] == 53.171875){
                return -1;
        }

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath//hidtemper");
		if($debug >=2){
			print "\t\tgetHidTEMPer $curTemp\n";
		}
	}
	return $curTemp;
}

#** @function public bcm2708Temp ()
# @brief get bcm2708 temperature 
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getBCM2708{
	my $curTemp;
	my @temp;
	
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
                $curTemp = $1;
        }

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath/bcm2708");
		if($debug >=2){
			print "\t\tgetBCM2708 $curTemp\n";
		}
	}
        return $curTemp;
}


#** @function public getTempDS1820 ($ID)
# @brief get DS1820 temperature 
# @param requiered $ID ID of Sensor
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub getTempDS1820{
	my $curTemp;
	my @temp;
	
	if($debug >= 3){
		print "\tgetTempDS1820\n";
	}

	open($fh, "<", "/sys/bus/w1/devices/$_[0]/w1_slave") or return "-1";
	#** @var @temp stores recived string
	@temp = <$fh>;
	close($fh);

        if(  !($temp[0] =~ m\YES\) ){
                return -1;
        }
	elsif( !($temp[1] =~ m\t=(.*)\) ){
		return -1;
	}
	elsif($1 < -55000 || $1 > 125000){
		return -1;
	}
	else{
		$curTemp = $1/1000;
		if($debug >= 1){
			system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath/ds1820_$_[0]");

        		open ($fh, "+>>$LogPath/ds1820_debug_$_[0]") || die "cant open file $LogPath/ds1820_debug_$_[0]: $!\n";
		        print $fh @temp;
			close $fh;
			if($debug >=2){
				print "\t\tgetTempDS1820 $curTemp\n";
			}
		}

		return $curTemp;
	}
}

#** @function public fillArray ($func, $count, $tolerance, $sensorID])
# @brief XXX
# @param required $func $_[0] XXX
# @param required $count $_[1] XXX
# @param required $tolerance $_[2] XXX
# @param required $sleep $_[3]
# @param optional $sensorID $_[4] XXX
# @todo if array value 'U' delete item
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub fillArray{
	my $i;
	#** @var @temperature stores multible temperatures
	my @temperature;
	#** @var @hydro stores multible hydro values 
	my @hydro;
	my $curTemp;
	my $curHydro;

	for($i=0; $i<$_[1]; $i++){
		# if Temperature+Hydro
		if( ($_[0]) eq (\&getDHT11) ){
			($temperature[$i], $hydro[$i]) = $_[0]($_[4]);
		}
		# if Temperature
		else{
			$temperature[$i] = $_[0]($_[4]);
		}
		sleep($_[3]);
	}
	

	if( ($_[0]) eq (\&getDHT11) ){
		return ( avgTemp(\@temperature), avgTemp(\@hydro) );
	}
	else{
		return avgTemp(\@temperature);;
	}
}



#** @function public avgTemp (@array)
# @brief get DS1820 temperature 
# @param required @array
# @todo if array value 'U' delete item
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub avgTemp{
	my @array = @{$_[0]};
	@array = sort @array;
	return $array[floor( ($#array+1)/2 )];
}

1;

