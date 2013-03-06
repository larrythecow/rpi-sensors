#!/usr/bin/perl

package sensors;

use strict;
use warnings;
use POSIX;
use Device::USB::PCSensor::HidTEMPer;
use Data::Dumper;
use Statistics::Basic qw(:all);
use Readonly;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.0.1';
@ISA         = qw(Exporter);
@EXPORT      = qw(getDHT11 getHidTEMPer getBCM2708 getTempDS1820 fillArray getValuesFromHash getSensorNameFromHash %func);

#** @var $fh default fileHandler
my $fh;
#** @var $debug debug flag
my $debug=0;
#** @var $LogPath debug log path
my $LogPath="/opt/tmp/sensor-debug";

#** @var %func references between sensorname and sensorfunction
Readonly::Hash our %func=>(
        ds1820 => \&getTempDS1820,
        bcm2708 => \&getBCM2708,
        hidtemper => \&getHidTEMPer,
        dht11 => \&getDHT11
);

#** @function public getDHT11($gpio)
# @brief get DHT11 temperature and humidity
# @param gpio required $_[0] GPIO PIN where sensor is connected
# @retval temperature if no error
# @retval U U=unknown, if error
#* 
sub getDHT11{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var $curHum stores current humidity
	my $curHum;
        #** @var @temp multi purporage storage
        my @temp;

        if($debug >= 3){
                print "\tgetDHT11\n";
        }

        if( !(-r '/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT') ){
                return ('U', 'U');
        }

        @temp = `/opt/rpi-sensors/lib/3rdparty/Adafruit-Raspberry-Pi-Python-Code/Adafruit_DHT_Driver/Adafruit_DHT 11 $_[0]`;
	
	if( !(defined $temp[2]) ){
		return ('U', 'U');
	}

        if( !($temp[2] =~ m/^Temp\ =\ (.*)\*C/) ){
                return ('U', 'U');
        }
        else{  
                $curTemp = $1;
        }

	if( !($temp[2] =~ m/Hum\ =\ (.*)\ \%/) ){
                return ('U', 'U');
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


#** @function public getHidTEMPer()
# @brief HidTEMPer temperature 
# @retval temperature if no error
# @retval U U=unknown, if error
#* 
sub getHidTEMPer{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var $temper stores HidTEMPer object
	my $temper;
	#** @var $sensor stores HidTEMPer sensor
	my $sensor;

        if($debug >= 3){
                print "\tgetHidTEMPer\n";
        }

	$temper = Device::USB::PCSensor::HidTEMPer->new();
	if(defined $temper){
		$sensor = $temper->device();
	}
	else{
		return 'U'
	}

	if(defined $sensor){
		$curTemp = $sensor->internal()->celsius();
	}
	else{
		return 'U';
	}

	if($curTemp < -40 || $curTemp > 120){	# || $curTemp[0] == 53.171875){
        	return 'U';
	}
	elsif($curTemp > 52 && $curTemp < 53){   # || $curTemp[0] == 53.171875){
        	return 'U';
        }
	
	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $curTemp >> $LogPath//hidtemper");
		if($debug >=2){
			print "\t\tgetHidTEMPer $curTemp\n";
		}
	}
	return $curTemp;
}

#** @function public getBCM2708()
# @brief bcm2708 temperature, raspberry CPU sensor 
# @retval temperature if no error
# @retval U U=unknown, if error
#*
sub getBCM2708{
	#** @var @temp multi purporage storage
	my @temp;
	
        if($debug >= 3){
                print "\tgetBCM2708\n";
        }

	open($fh, "<", "/sys/devices/virtual/thermal/thermal_zone0/temp") or return "U";
	@temp = <$fh>;
	close($fh);

	if($debug >= 1){
		system("echo `date +%Y-%m-%d_%H:%M:%S` $temp[0] >> $LogPath/bcm2708");
		if($debug >=2){
			print "\t\tgetBCM2708 $temp[0]/1000\n";
		}
	}
        return ($temp[0]/1000);
}


#** @function public getTempDS1820 ($UID)
# @brief get DS1820 temperature 
# @param UID required $_[0] UID of Sensor
# @retval temperature if no error
# @retval U U=unknown, if error
#* 
sub getTempDS1820{
	#** @var @curTemp stores current temperature
	my $curTemp;
	#** @var @temp multi purporage storage
	my @temp;
	
	if($debug >= 3){
		print "\tgetTempDS1820\n";
	}

	open($fh, "<", "/sys/bus/w1/devices/$_[0]/w1_slave") or return "U";
	@temp = <$fh>;
	close($fh);

        if(  !($temp[0] =~ m\YES\) ){
                return 'U';
        }
	elsif( !($temp[1] =~ m\t=(.*)\) ){
		return 'U';
	}
	elsif($1 < -55000 || $1 > 125000){
		return 'U';
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

#** @function public fillArray ($func, $count, $sleep, $sensorID)
# @brief call sensor function count-times and return AVG value
# @param func required $_[0] sensor function which will be called 
# @param count required $_[1] run $func n time
# @param sleep required $_[2] delay between measure
# @param sensorID optional $_[3] UID or GPIO of sensor
# @retval temperature if no error
# @retval U U=unknown, if error
#* 
sub fillArray{
	my $i;
	#** @var @temperature stores multible temperatures
	my @temperature;
	#** @var @humidity stores multible hydro values 
	my @humidity;
	
	my $curHydro;

	for($i=0; $i<$_[1]; $i++){
		# if temperature+humidity
		if( ($_[0]) eq (\&getDHT11) ){
			($temperature[$i], $humidity[$i]) = $_[0]($_[3]);
		}
		# if Temperature
		else{
			$temperature[$i] = $_[0]($_[3]);
		}
		sleep($_[2]);
	}
	

	if( ($_[0]) eq (\&getDHT11) ){
		return ( avgTemp(\@temperature), avgTemp(\@humidity) );
	}
	else{
		return avgTemp(\@temperature);;
	}
}



#** @function public avgTemp (@array)
# @brief remove false measures and return mean 
# @param array required $_[0] 
# @retval temperature if no error
# @retval U U=unknown, if erro
#* 
sub avgTemp{
	my @array = @{$_[0]};

	my $pos=0;
	while (defined $array[$pos]){
        if ($array[$pos] =~ m/U/ ){
                splice(@array, $pos, 1);
        }
        else{   
                $pos++;
        }
}

	if( !(defined $array[0]) ){
        	return 'U';
	}
	return mean(@array);
}

#** @function public getValuesFromHash (%hash, $sensorType, $sensorID)
# @brief return temperature and/or humidity from yml file
# @param hash required $_[0]
# @param sensorType required $_[1]
# @param sensorID required $_[2]
# @retval $temperature if temperature sensor 
# @retval U U=unknown, if error
#*
sub getValuesFromHash{
my %yml = %{$_[0]};
my $sensorType = $_[1];
my $sensorID = $_[2];
my $sensorName;
my $temperature;
my $humidity;

if( !(defined $sensorID) ){
	$sensorID=0;
}
	foreach my $type(%yml){
        	if($type eq $sensorType){
	                my $i=0;
                        	foreach my $id ( @{$yml{$type}->{id}} ){
                                	if($id eq $sensorID){
	                                        $temperature=$yml{$sensorType}->{'temperature'}->[$i];
        	                                $sensorName = $yml{$sensorType}->{'name'}->[$i];
                	                        if(defined $yml{$sensorType}->{'humidity'}->[$i]){
                        	                        $humidity=$yml{$sensorType}->{'humidity'}->[$i];
                                	        }
	                                }
        	                        $i++;
                	        }
        	}
	}

if (defined $humidity){
	return ($temperature, $humidity);
}
else{
	return $temperature;
}

}

#** @function public getSensorNameFromHash (%hash, $sensorType, $sensorID)
# @brief get sensor name 
# @param hash required $_[0] 
# @param sensorType required $_[1]
# @param sensorID optional $[2]
# @retval sensorName OK 
# @retval -1 ERROR
#*
sub getSensorNameFromHash{
my %yml = %{$_[0]};
my $sensorType = $_[1];
my $sensorID = $_[2];
my $sensorName;

if( !(defined $sensorID) ){
        $sensorID=0;
}
        foreach my $type(%yml){
                if($type eq $sensorType){
                        my $i=0;
                                foreach my $id ( @{$yml{$type}->{id}} ){
                                        if($id eq $sensorID){
                                                return $yml{$sensorType}->{'name'}->[$i];
                                        }
                                        $i++;
                                }
                }
        }

        return -1;
}

1;

